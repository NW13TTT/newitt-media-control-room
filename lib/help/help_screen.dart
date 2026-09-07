import 'package:flutter/material.dart';

import 'help_guides.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, this.initialGuideId});
  final String? initialGuideId;
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _query = '';
  String _category = 'All';
  HelpGuide? _selected;
  @override
  void initState() {
    super.initState();
    _selected = helpGuides
        .where((guide) => guide.id == widget.initialGuideId)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final visible = helpGuides
        .where(
          (guide) =>
              (_category == 'All' || guide.category == _category) &&
              '${guide.title} ${guide.summary}'.toLowerCase().contains(
                _query.toLowerCase(),
              ),
        )
        .toList();
    return Scaffold(
      body: SafeArea(
        child: _selected == null ? _list(visible) : _detail(_selected!),
      ),
    );
  }

  Widget _list(List<HelpGuide> guides) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How To',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Clear guidance for your Control Room.',
              style: TextStyle(color: Color(0xFF8A99A5)),
            ),
            const SizedBox(height: 24),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search guides',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in helpCategories)
                  ChoiceChip(
                    label: Text(category),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (guides.isEmpty)
              const _HelpEmpty()
            else
              ...guides.map(
                (guide) => ListTile(
                  leading: Icon(guide.icon, color: const Color(0xFF00D9F5)),
                  title: Text(guide.title),
                  subtitle: Text(guide.summary),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _selected = guide),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  Widget _detail(HelpGuide guide) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _selected = null),
              icon: const Icon(Icons.arrow_back),
              label: const Text('All guides'),
            ),
            const SizedBox(height: 18),
            Icon(guide.icon, color: const Color(0xFF00D9F5), size: 32),
            const SizedBox(height: 12),
            Text(
              guide.title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              guide.summary,
              style: const TextStyle(color: Color(0xFFB6C3CB), height: 1.5),
            ),
            const SizedBox(height: 24),
            for (var index = 0; index < guide.steps.length; index++)
              ListTile(
                leading: CircleAvatar(
                  radius: 13,
                  backgroundColor: const Color(0xFF102B35),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Color(0xFF00D9F5)),
                  ),
                ),
                title: Text(guide.steps[index]),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF151B24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                guide.note,
                style: const TextStyle(color: Color(0xFFE9B949)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HelpEmpty extends StatelessWidget {
  const _HelpEmpty();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(36),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_outlined, size: 36, color: Color(0xFF00D9F5)),
          SizedBox(height: 12),
          Text('No guides found'),
          SizedBox(height: 5),
          Text(
            'Try a different search or category.',
            style: TextStyle(color: Color(0xFF8A99A5)),
          ),
        ],
      ),
    ),
  );
}

void openHelpGuide(BuildContext context, String guideId) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HelpScreen(initialGuideId: guideId),
      ),
    );
