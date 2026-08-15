import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gazette_dataset.dart';
import '../models/gazette_record.dart';

/// Owns "which gazette is currently loaded" and persists an uploaded
/// gazette to disk so it survives app restarts (the old web version lost
/// an uploaded PDF's parsed data the moment you refreshed the page — this
/// fixes that too).
class GazetteRepository extends ChangeNotifier {
  GazetteDataset? _dataset;
  bool _loading = true;
  String? _loadError;

  GazetteDataset? get dataset => _dataset;
  bool get isLoading => _loading;
  String? get loadError => _loadError;

  static const _prefsKeyUsingUpload = 'result_desk_using_upload';
  static const _uploadFileName = 'uploaded_gazette.json';

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final usingUpload = prefs.getBool(_prefsKeyUsingUpload) ?? false;
      if (usingUpload) {
        final loaded = await _loadUploadFromDisk();
        if (loaded != null) {
          _dataset = loaded;
          _loading = false;
          notifyListeners();
          return;
        }
      }
      _dataset = await _loadBundled();
    } catch (e) {
      _loadError = 'Could not load gazette data: $e';
    }
    _loading = false;
    notifyListeners();
  }

  Future<GazetteDataset> _loadBundled() async {
    final raw = await rootBundle.loadString('assets/data/bundled_gazette.json');
    final metaRaw = await rootBundle.loadString('assets/data/bundled_gazette_meta.json');
    final meta = jsonDecode(metaRaw) as Map<String, dynamic>;
    final list = jsonDecode(raw) as List<dynamic>;
    final records = list
        .map((e) => GazetteRecord.fromLegacyArray(e as List<dynamic>))
        .toList(growable: false);
    return GazetteDataset(
      boardId: meta['boardId'] as String? ?? 'bise_lahore',
      boardName: meta['boardName'] as String? ?? '',
      examName: meta['examName'] as String? ?? '',
      examYear: meta['examYear'] as String? ?? '',
      sourceLabel: meta['sourceLabel'] as String? ?? 'Bundled dataset',
      records: records,
    );
  }

  Future<File> _uploadFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_uploadFileName');
  }

  Future<GazetteDataset?> _loadUploadFromDisk() async {
    try {
      final file = await _uploadFile();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final records = (map['records'] as List<dynamic>)
          .map((e) => GazetteRecord.fromLegacyArray(e as List<dynamic>))
          .toList(growable: false);
      return GazetteDataset(
        boardId: map['boardId'] as String? ?? 'custom_upload',
        boardName: map['boardName'] as String? ?? 'Uploaded gazette',
        examName: map['examName'] as String? ?? '',
        examYear: map['examYear'] as String? ?? '',
        sourceLabel: map['sourceLabel'] as String? ?? 'Uploaded gazette',
        records: records,
        warnings: (map['warnings'] as List<dynamic>? ?? []).cast<String>(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Persists a freshly-parsed dataset and makes it the active one.
  Future<void> adoptParsedDataset(GazetteDataset ds) async {
    _dataset = ds;
    notifyListeners();

    final file = await _uploadFile();
    final map = {
      'boardId': ds.boardId,
      'boardName': ds.boardName,
      'examName': ds.examName,
      'examYear': ds.examYear,
      'sourceLabel': ds.sourceLabel,
      'warnings': ds.warnings,
      'records': ds.records.map((r) => r.toLegacyArray()).toList(),
    };
    await file.writeAsString(jsonEncode(map));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyUsingUpload, true);
  }

  /// Reverts back to the bundled default gazette.
  Future<void> revertToBundled() async {
    _loading = true;
    notifyListeners();
    _dataset = await _loadBundled();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyUsingUpload, false);
    _loading = false;
    notifyListeners();
  }

  // --------------------------- Search ---------------------------------

  List<GazetteRecord> search({
    String nameOrRoll = '',
    String dob = '',
    ResultStatus? category,
    int limit = 5000,
  }) {
    final ds = _dataset;
    if (ds == null) return const [];
    final rawName = nameOrRoll.trim();
    final rawDob = dob.trim();
    if (rawName.isEmpty && rawDob.isEmpty) return const [];

    final isRollQuery = RegExp(r'^\d+$').hasMatch(rawName);
    final nameTokens = (!isRollQuery && rawName.isNotEmpty)
        ? rawName.toUpperCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList()
        : const <String>[];
    final dobQuery = _normalizeDobQuery(rawDob);

    final out = <GazetteRecord>[];
    for (final rec in ds.records) {
      if (category != null && rec.status != category) continue;

      if (isRollQuery) {
        if (!rec.rollNumber.toString().contains(rawName)) continue;
      } else if (nameTokens.isNotEmpty) {
        final upper = rec.name.toUpperCase();
        var ok = true;
        for (final t in nameTokens) {
          if (!upper.contains(t)) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
      }

      if (dobQuery != null && !_dobMatches(rec.dob, dobQuery)) continue;

      out.add(rec);
      if (out.length >= limit) break;
    }
    return out;
  }

  _DobQuery? _normalizeDobQuery(String q) {
    if (q.isEmpty) return null;
    final parts = q.split(RegExp(r'[/\-.]')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    String dd = '', mm = '', yy = '';
    if (parts.isNotEmpty) dd = parts[0];
    if (parts.length >= 2) mm = parts[1];
    if (parts.length >= 3) yy = parts[2];
    if (dd.length == 1) dd = '0$dd';
    if (mm.length == 1) mm = '0$mm';
    if (yy.length == 4) yy = yy.substring(2);
    return _DobQuery(dd, mm, yy);
  }

  bool _dobMatches(String? recordDob, _DobQuery q) {
    if (recordDob == null) return false;
    final parts = recordDob.split('/');
    if (parts.length != 3) return false;
    if (q.dd.isNotEmpty && q.dd != parts[0]) return false;
    if (q.mm.isNotEmpty && q.mm != parts[1]) return false;
    if (q.yy.isNotEmpty && q.yy != parts[2]) return false;
    return true;
  }
}

class _DobQuery {
  final String dd, mm, yy;
  _DobQuery(this.dd, this.mm, this.yy);
}
