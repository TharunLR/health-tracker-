import 'package:flutter/material.dart';
import '../services/gamification_service.dart';

class GamifiedBadgesCard extends StatelessWidget {
  const GamifiedBadgesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GamificationState>(
      stream: GamificationService.instance.stateStream,
      initialData: GamificationService.instance.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ??
            const GamificationState(
              xpPoints: 350,
              currentStreak: 3,
              level: 2,
              badges: [],
            );

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Level / Streak Badges
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFF7A59), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level ${state.level} Health Explorer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111111),
                        ),
                      ),
                      Text(
                        '${state.xpPoints} total XP earned',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6F6A64)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Active Streak Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE0B2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFF9800), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Text('🔥 ', style: TextStyle(fontSize: 13)),
                        Text(
                          '${state.currentStreak} Day Streak',
                          style: const TextStyle(
                            color: Color(0xFFE65100),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Achievements Grid / List
              const Text(
                'Active Health Badges',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A4640),
                ),
              ),
              const SizedBox(height: 10),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.badges.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final badge = state.badges[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: badge.unlocked ? const Color(0xFFF4F9F4) : const Color(0xFFF8F6F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: badge.unlocked ? const Color(0xFFA5D6A7) : const Color(0xFFECE6DD),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(badge.icon, style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    badge.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: badge.unlocked ? const Color(0xFF1B5E20) : const Color(0xFF111111),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (badge.unlocked)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC8E6C9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'UNLOCKED!',
                                        style: TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                badge.description,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6F6A64)),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: badge.progress,
                                  minHeight: 5,
                                  backgroundColor: const Color(0xFFE5DFD7),
                                  color: badge.unlocked ? const Color(0xFF4CAF50) : const Color(0xFFFF7A59),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
