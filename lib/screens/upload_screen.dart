import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gazette_repository.dart';
import '../services/pdf_gazette_parser.dart';
import '../theme/app_theme.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _parsing = false;
  int _currentPage = 0;
  int _totalPages = 0;
  int _found = 0;
  String? _error;
  List<String> _lastWarnings = [];
  String? _lastFileName;

  Future<void> _pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) {
      setState(() => _error = 'Could not read the selected file.');
      return;
    }

    setState(() {
      _parsing = true;
      _error = null;
      _currentPage = 0;
      _totalPages = 0;
      _found = 0;
      _lastWarnings = [];
      _lastFileName = file.name;
    });

    try {
      final dataset = await PdfGazetteParser.parse(
        bytes,
        fileLabel: file.name,
        onProgress: (page, total, found) {
          if (!mounted) return;
          setState(() {
            _currentPage = page;
            _totalPages = total;
            _found = found;
          });
        },
      );

      if (!mounted) return;
      await context.read<GazetteRepository>().adoptParsedDataset(dataset);

      setState(() {
        _parsing = false;
        _lastWarnings = dataset.warnings;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Indexed ${dataset.total} candidates from ${file.name}'),
            backgroundColor: AppColors.navy,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _parsing = false;
        _error = 'Could not parse this PDF: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GazetteRepository>();
    final ds = repo.dataset;
    final progress = _totalPages == 0 ? 0.0 : _currentPage / _totalPages;

    return Scaffold(
      appBar: AppBar(title: const Text('Load a gazette PDF')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Universal gazette parser',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Works with any board result gazette (roll number, name, date of '
            'birth, result status table) — not just the one this app ships '
            'with. Columns are detected automatically from each page, so a '
            'different board or a different exam\'s gazette should parse '
            'correctly. Parsing happens entirely on your device; nothing is '
            'uploaded anywhere.',
            style: TextStyle(color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 20),
          if (ds != null && !_parsing)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: AppColors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Currently loaded: ${ds.sourceLabel} · ${ds.total} candidates',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          if (!_parsing)
            ElevatedButton.icon(
              onPressed: _pickAndParse,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose gazette PDF'),
            ),
          if (repo.dataset?.boardId == 'custom_upload' && !_parsing) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await context.read<GazetteRepository>().revertToBundled();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reverted to the bundled gazette')),
                  );
                }
              },
              icon: const Icon(Icons.restore),
              label: const Text('Revert to bundled gazette'),
            ),
          ],
          if (_parsing) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: _totalPages == 0 ? null : progress),
            const SizedBox(height: 10),
            Text(
              _totalPages == 0
                  ? 'Opening PDF…'
                  : 'Parsing page $_currentPage of $_totalPages · $_found candidates found so far',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.fail.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.fail, fontSize: 13)),
            ),
          ],
          if (_lastWarnings.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '${_lastWarnings.length} note(s) from parsing $_lastFileName',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Nothing was silently dropped — anything the parser wasn\'t '
              'fully sure about is listed here so you can double check it.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            ..._lastWarnings.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.withheld.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(w, style: const TextStyle(fontSize: 12)),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
