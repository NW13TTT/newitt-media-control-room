import 'package:flutter/material.dart';

import 'ai_service.dart';
import 'ai_permissions.dart';
import '../auth/auth_models.dart';
import '../core/layout/responsive.dart';
import '../help/smart_help_button.dart';

class AiControlScreen extends StatefulWidget {
  const AiControlScreen({
    super.key,
    this.service = const UnconfiguredAiService(),
    this.session,
  });

  final AiService service;
  final AuthSession? session;

  @override
  State<AiControlScreen> createState() => _AiControlScreenState();
}

class _AiControlScreenState extends State<AiControlScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _hasRequest = false;
  bool _sending = false;
  String? _message;
  final List<String> _history = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (_controller.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _sending = true;
      _message = null;
    });
    final request = _controller.text.trim();
    try {
      final response = await widget.service.submit(request);
      if (mounted) {
        setState(() {
          _history.add(request);
          _hasRequest = true;
          _message = response.message;
          _sending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _history.add(request);
          _hasRequest = true;
          _message = 'AI is temporarily unavailable.';
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = AiPermissionPolicy(widget.session);
    return SingleChildScrollView(
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 30),
            _buildIntroduction(),
            const SizedBox(height: 24),
            if (!widget.service.isConfigured) _buildUnavailableNotice(),
            if (!widget.service.isConfigured) const SizedBox(height: 16),
            _buildPermissionNotice(policy),
            const SizedBox(height: 16),
            _buildControlBox(),
            const SizedBox(height: 24),
            _buildSafetyNotice(),
            const SizedBox(height: 24),
            _buildExamples(),
            if (_hasRequest) ...[
              const SizedBox(height: 24),
              _buildRequestPreview(),
            ],
            if (_history.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _history.clear();
                    _hasRequest = false;
                    _message = null;
                    _controller.clear();
                  }),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear conversation'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionNotice(AiPermissionPolicy policy) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF111922),
      border: Border.all(color: const Color(0xFF26343D)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, color: Color(0xFF00D9F5)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI permission: ${policy.label}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Align(
                alignment: Alignment.centerRight,
                child: SmartHelpButton(
                  guideId: 'ai-permissions',
                  tooltip: 'AI permissions help',
                ),
              ),
              const SizedBox(height: 5),
              Text(
                policy.level == AiPermissionLevel.assist
                    ? 'AI may explain information only.'
                    : policy.level == AiPermissionLevel.draft
                    ? 'AI may assist and prepare drafts for your own website. Publishing still requires your approval.'
                    : 'AI may assist and prepare drafts. Any publish action requires explicit human approval.',
                style: const TextStyle(
                  color: Color(0xFFB6C3CB),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'AI cannot change infrastructure, security, payments, Storage, or deployments.',
                style: TextStyle(color: Color(0xFFE9B949), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'AI Control',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF10251C),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 4, backgroundColor: Color(0xFF4ADE80)),
              SizedBox(width: 8),
              Text(
                'AI not configured',
                style: TextStyle(fontSize: 12, color: Color(0xFF8DE7AA)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnavailableNotice() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF151B24),
      border: Border.all(color: const Color(0xFF263543)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.cloud_off_outlined, color: Color(0xFFE9B949)),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'AI is not configured. Your request stays in this Control Room and no AI provider is contacted.',
            style: TextStyle(color: Color(0xFFB6C3CB), fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _buildIntroduction() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tell the Control Room what you need.',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Text(
          'Use normal language. The Control Room will understand your request, check what it is allowed to do, and prepare the appropriate action.',
          style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF7F8B95)),
        ),
      ],
    );
  }

  Widget _buildControlBox() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101A22), Color(0xFF0C131A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF17404A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF00D9F5), size: 22),
              SizedBox(width: 10),
              Text(
                'AI Control Box',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Describe the result you want. You do not need to know how the website works.',
            style: TextStyle(fontSize: 13, color: Color(0xFF84919B)),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerRight,
            child: SmartHelpButton(
              guideId: 'ai-control',
              tooltip: 'AI Control help',
            ),
          ),
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 8,
            onChanged: (_) {
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Example:\nAdd these three wedding photos to my 2026 gallery and put the newest one first.',
              hintStyle: const TextStyle(
                color: Color(0xFF596670),
                fontSize: 13,
                height: 1.5,
              ),
              filled: true,
              fillColor: const Color(0xFF080D12),
              contentPadding: const EdgeInsets.all(18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF25333D)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF25333D)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00A8C4)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final submit = ElevatedButton.icon(
                onPressed: _sending || _controller.text.trim().isEmpty
                    ? null
                    : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A8C4),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF1A2A31),
                  disabledForegroundColor: const Color(0xFF52616A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.arrow_upward, size: 18),
                label: Text(
                  _sending ? 'Sending...' : 'Send request',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              );
              final note = const Text(
                'The AI will never bypass your Control Room permissions.',
                style: TextStyle(fontSize: 11, color: Color(0xFF65737D)),
              );
              if (constraints.maxWidth < ControlRoomBreakpoints.phone) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    note,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: submit),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: note),
                  const SizedBox(width: 16),
                  submit,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyNotice() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111922),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF26343D)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF00C6E6), size: 22),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Controlled by NEWITT permissions',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 5),
                Text(
                  'Requests are checked against your website capabilities, account permissions and safety rules before anything can be changed.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: Color(0xFF74828C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamples() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Things you can ask for',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _exampleCard(
                Icons.photo_library_outlined,
                'Manage photos',
                'Add, organise or reorder images.',
              ),
              _exampleCard(
                Icons.edit_note_outlined,
                'Update content',
                'Change text, pages or information.',
              ),
              _exampleCard(
                Icons.public_outlined,
                'Website changes',
                'Request approved website updates.',
              ),
            ];

            if (constraints.maxWidth < 700) {
              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    if (card != cards.last) const SizedBox(height: 12),
                  ],
                ],
              );
            }

            return Row(
              children: [
                for (int index = 0; index < cards.length; index++) ...[
                  Expanded(child: cards[index]),
                  if (index < cards.length - 1) const SizedBox(width: 14),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _exampleCard(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D141B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B2730)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00C6E6), size: 23),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(
              fontSize: 10,
              height: 1.4,
              color: Color(0xFF73808A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestPreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF101A20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1D5965)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.pending_actions_outlined,
                color: Color(0xFF00D9F5),
                size: 21,
              ),
              SizedBox(width: 10),
              Text(
                'Request received',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _controller.text.trim(),
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFFADB6BD),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _message ?? 'Request recorded locally.',
            style: const TextStyle(fontSize: 11, color: Color(0xFF65737D)),
          ),
        ],
      ),
    );
  }
}
