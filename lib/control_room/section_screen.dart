import 'package:flutter/material.dart';

import '../core/layout/responsive.dart';

class ControlRoomSectionScreen extends StatelessWidget {
  const ControlRoomSectionScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.statusText,
    required this.cards,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String statusText;
  final List<ControlRoomCardData> cards;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080B10),
      child: SingleChildScrollView(
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF102B35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: const Color(0xFF00D9F5), size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7F8B95),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1718),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF173B35)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF54D68B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Color(0xFFD7E3E8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF54D68B),
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final int columns = constraints.maxWidth >= 1100
                      ? 3
                      : constraints.maxWidth >= 700
                      ? 2
                      : 1;

                  if (columns == 1) {
                    return Column(
                      children: cards
                          .map(
                            (card) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: SizedBox(
                                height: 180,
                                child: _buildCard(card),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cards.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.1,
                    ),
                    itemBuilder: (context, index) {
                      return _buildCard(cards[index]);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(ControlRoomCardData card) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D141C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF182530)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF102B35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  card.icon,
                  color: const Color(0xFF00D9F5),
                  size: 20,
                ),
              ),
              const Spacer(),
              if (card.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF102B35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    card.badge!,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00D9F5),
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            card.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            card.description,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Color(0xFF71808B),
            ),
          ),
        ],
      ),
    );
  }
}

class ControlRoomCardData {
  const ControlRoomCardData({
    required this.title,
    required this.description,
    required this.icon,
    this.badge,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? badge;
}
