import 'package:flutter/material.dart';

import '../backend/control_room_repository.dart';

class ContentSectionEditor extends StatefulWidget {
  const ContentSectionEditor({
    super.key,
    required this.repository,
    required this.initialSections,
    required this.onChanged,
  });

  final ControlRoomRepository repository;
  final List<Map<String, dynamic>> initialSections;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  @override
  State<ContentSectionEditor> createState() => _ContentSectionEditorState();
}

class _ContentSectionEditorState extends State<ContentSectionEditor> {
  late List<Map<String, dynamic>> sections = widget.initialSections
      .map((section) => Map<String, dynamic>.from(section))
      .toList();

  void _notify() => widget.onChanged(
    sections.map((section) => Map<String, dynamic>.from(section)).toList(),
  );

  Future<void> _addSection() async {
    final type = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add section'),
        children: [
          for (final item in const {
            'heading': 'Heading',
            'text': 'Rich text',
            'image': 'Image from Media Library',
            'gallery': 'Image gallery',
            'video': 'Video from Media Library',
            'external_video': 'External video link',
            'button': 'Button or link',
            'investigation': 'Investigation card',
            'location': 'Location card',
            'featured': 'Featured content',
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item.key),
              child: Text(item.value),
            ),
        ],
      ),
    );
    if (type == null || !mounted) return;

    Map<String, dynamic> section = {'type': type};
    if (type == 'image' || type == 'video' || type == 'gallery') {
      final media = await showDialog<MediaRecord>(
        context: context,
        builder: (_) => _MediaChooser(repository: widget.repository),
      );
      if (media == null || !mounted) return;
      section = {
        ...section,
        'mediaId': media.id,
        'title': media.title ?? 'Selected media',
      };
    } else if (type == 'external_video' || type == 'button') {
      final value = await showDialog<String>(
        context: context,
        builder: (_) => _SectionValueDialog(
          title: type == 'button' ? 'Button link' : 'Video URL',
          hint: type == 'button'
              ? 'https://example.com'
              : 'https://youtube.com/...',
        ),
      );
      if (value == null || !mounted) return;
      section['url'] = value;
    }
    setState(() => sections.add(section));
    _notify();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Page sections',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton.icon(
            onPressed: _addSection,
            icon: const Icon(Icons.add),
            label: const Text('Add section'),
          ),
        ],
      ),
      if (sections.isEmpty)
        const Text(
          'Add headings, text, media, links, or feature cards without writing code.',
          style: TextStyle(color: Color(0xFF8A99A5), fontSize: 12),
        )
      else
        ...sections.asMap().entries.map(
          (entry) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.drag_indicator),
            title: Text(
              _sectionLabel(entry.value['type'] as String? ?? 'text'),
            ),
            subtitle: Text(
              '${entry.value['title'] ?? entry.value['url'] ?? 'Ready to configure'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Remove section',
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => sections.removeAt(entry.key));
                _notify();
              },
            ),
          ),
        ),
    ],
  );

  String _sectionLabel(String type) => type
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

class _MediaChooser extends StatelessWidget {
  const _MediaChooser({required this.repository});
  final ControlRoomRepository repository;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose from Media Library'),
    content: SizedBox(
      width: 560,
      child: FutureBuilder<List<MediaRecord>>(
        future: repository.listMedia(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final media = snapshot.data!;
          if (media.isEmpty) {
            return const Text('No media is available for this website yet.');
          }
          return SingleChildScrollView(
            child: Column(
              children: media
                  .map(
                    (item) => ListTile(
                      leading: Icon(
                        '${item.metadata['type']}'.startsWith('video/')
                            ? Icons.videocam_outlined
                            : Icons.image_outlined,
                      ),
                      title: Text(item.title ?? 'Untitled media'),
                      subtitle: Text('${item.metadata['type'] ?? 'Media'}'),
                      onTap: () => Navigator.pop(context, item),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

class _SectionValueDialog extends StatefulWidget {
  const _SectionValueDialog({required this.title, required this.hint});
  final String title;
  final String hint;
  @override
  State<_SectionValueDialog> createState() => _SectionValueDialogState();
}

class _SectionValueDialogState extends State<_SectionValueDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(hintText: widget.hint),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final value = controller.text.trim();
          if (value.isNotEmpty && Uri.tryParse(value)?.hasScheme == true) {
            Navigator.pop(context, value);
          }
        },
        child: const Text('Add'),
      ),
    ],
  );
}
