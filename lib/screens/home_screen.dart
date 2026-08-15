import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gazette_record.dart';
import '../services/gazette_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_info.dart';
import '../widgets/category_chips.dart';
import '../widgets/result_card.dart';
import '../widgets/stats_strip.dart';
import 'upload_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  ResultStatus? _category;
  List<GazetteRecord> _results = [];
  bool _searched = false;

  void _runSearch() {
    final repo = context.read<GazetteRepository>();
    setState(() {
      _searched = _nameCtrl.text.trim().isNotEmpty || _dobCtrl.text.trim().isNotEmpty;
      _results = repo.search(
        nameOrRoll: _nameCtrl.text,
        dob: _dobCtrl.text,
        category: _category,
      );
    });
  }

  void _clear() {
    _nameCtrl.clear();
    _dobCtrl.clear();
    setState(() {
      _category = null;
      _results = [];
      _searched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GazetteRepository>();

    return Scaffold(
      body: repo.isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildMasthead(context, repo)),
                SliverToBoxAdapter(child: _buildSearchPanel()),
                if (!_searched)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else if (_results.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _NoResultsState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => ResultCard(record: _results[i]),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildMasthead(BuildContext context, GazetteRepository repo) {
    final ds = repo.dataset;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyDeep, AppColors.navy],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppInfo.appName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white70),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.upload_file, color: Colors.white70),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UploadScreen()),
                  ),
                ),
              ],
            ),
            if (ds != null) ...[
              const SizedBox(height: 4),
              Text(
                ds.boardName.isNotEmpty ? ds.boardName : ds.sourceLabel,
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12.5),
              ),
              if (ds.examName.isNotEmpty)
                Text(
                  '${ds.examName}${ds.examYear.isNotEmpty ? ' · ${ds.examYear}' : ''}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11.5),
                ),
              const SizedBox(height: 16),
              StatsStrip(dataset: ds),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name or roll number',
              hintText: 'e.g. AYESHA TAHIR or 100121',
            ),
            onSubmitted: (_) => _runSearch(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _dobCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Date of birth',
              hintText: 'DD/MM/YYYY',
            ),
            onSubmitted: (_) => _runSearch(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _runSearch,
                  child: const Text('Search'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _clear,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CategoryChips(
            selected: _category,
            onSelect: (v) {
              setState(() => _category = v);
              if (_nameCtrl.text.trim().isNotEmpty || _dobCtrl.text.trim().isNotEmpty) {
                _runSearch();
              }
            },
          ),
          if (_searched && _results.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${_results.length} matching entr${_results.length == 1 ? 'y' : 'ies'}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 44, color: AppColors.textMuted),
          SizedBox(height: 14),
          Text('Begin your search', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          SizedBox(height: 6),
          Text(
            'Enter a candidate\'s name, roll number, or date of birth above.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 44, color: AppColors.textMuted),
          SizedBox(height: 14),
          Text('No matching record', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          SizedBox(height: 6),
          Text(
            'Double-check the spelling, roll number, or date format (DD/MM/YYYY).',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
