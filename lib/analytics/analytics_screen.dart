import 'package:flutter/material.dart';

import '../backend/control_room_repository.dart';
import '../core/layout/responsive.dart';
import '../help/smart_help_button.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key, required this.repository});
  final ControlRoomRepository? repository;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      color: const Color(0xFF080B10),
      child: SingleChildScrollView(
        child: ResponsiveContent(
          child: Center(
            child: repository == null
                ? const Text('Analytics unavailable.')
                : FutureBuilder<AnalyticsSummaryRecord>(
                    future: repository!.getAnalyticsSummary(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final data = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Analytics',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SmartHelpButton(
                                guideId: 'analytics',
                                tooltip: 'Analytics help',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Operational Analytics: Available',
                            style: TextStyle(color: Color(0xFF00D9F5)),
                          ),
                          const Text(
                            'Visitor Analytics: Not Connected',
                            style: TextStyle(color: Color(0xFF8A99A5)),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _Metric('Websites', data.websites),
                              _Metric('Content', data.content),
                              _Metric('Published', data.published),
                              _Metric('Media', data.media),
                              _Metric('Open support', data.supportOpen),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No external visitor tracking provider is connected.',
                            style: TextStyle(color: Color(0xFF8A99A5)),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0D141C),
      border: Border.all(color: const Color(0xFF1B2A35)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: Color(0xFF00D9F5),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label, style: const TextStyle(color: Color(0xFF8A99A5))),
      ],
    ),
  );
}
