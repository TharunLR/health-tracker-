import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/steps_service.dart';

class WeeklyStepsGraphCard extends StatefulWidget {
  const WeeklyStepsGraphCard({super.key});

  @override
  State<WeeklyStepsGraphCard> createState() => _WeeklyStepsGraphCardState();
}

class _WeeklyStepsGraphCardState extends State<WeeklyStepsGraphCard> {
  int _selectedIndex = 29; // Today default
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StepsSnapshot>(
      stream: StepsService.instance.stepsStream,
      initialData: StepsService.instance.currentSnapshot,
      builder: (context, stepsSnapshot) {
        final stepsToday = stepsSnapshot.data?.stepsToday ?? 0;

        return StreamBuilder<WeeklyStepsSnapshot>(
          stream: StepsService.instance.weeklyStepsStream,
          initialData: StepsService.instance.currentWeeklySnapshot,
          builder: (context, snapshot) {
            final monthlyHistory = snapshot.data?.monthlyHistory ?? [];
            final now = DateTime.now();

            final List<DailyStepsEntry> history30 = [];
            for (var i = 29; i >= 0; i--) {
              final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
              int steps = 0;
              final match = monthlyHistory.firstWhere(
                (h) => h.date.year == date.year && h.date.month == date.month && h.date.day == date.day,
                orElse: () => DailyStepsEntry(date: date, steps: 0),
              );
              steps = match.steps;
              if (i == 0) steps = stepsToday;
              history30.add(DailyStepsEntry(date: date, steps: steps));
            }

            final safeIndex = _selectedIndex.clamp(0, history30.length - 1);
            final selectedEntry = history30[safeIndex];
            final selectedSteps = selectedEntry.steps;
            const int stepGoal = 8000;

            int maxStep = 0;
            for (final entry in history30) {
              if (entry.steps > maxStep) maxStep = entry.steps;
            }
            final double highestValue = math.max(maxStep.toDouble(), stepGoal * 1.15);

            final isTodaySelected = safeIndex == 29;
            final dateLabel = isTodaySelected
                ? 'Today'
                : '${selectedEntry.date.day}/${selectedEntry.date.month}';

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '30-Day Activity Calendar',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: const Color(0xFF111111),
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scroll horizontally to view 30 days history',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF6F6A64),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_walk_rounded, size: 16, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 4),
                            Text(
                              '$dateLabel: $selectedSteps',
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 30-Day Horizontal Scroll Bar Chart
                  SizedBox(
                    height: 165,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(history30.length, (index) {
                          final entry = history30[index];
                          final steps = entry.steps;
                          final heightFactor = (steps / highestValue).clamp(0.05, 1.0);
                          final isSelected = index == safeIndex;
                          final meetsGoal = steps >= stepGoal;
                          final isToday = index == 29;

                          final dayLabel = isToday
                              ? 'Today'
                              : '${entry.date.day}/${entry.date.month}';

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: SizedBox(
                                width: 32,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (isSelected)
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: meetsGoal ? const Color(0xFF2E7D32) : const Color(0xFF111111),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$steps',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 14),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      width: isSelected ? 18 : 12,
                                      height: 100 * heightFactor,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: meetsGoal
                                              ? [const Color(0xFF2E7D32), const Color(0xFF4CAF50)]
                                              : (isSelected
                                                  ? [const Color(0xFF1565C0), const Color(0xFF64B5F6)]
                                                  : [const Color(0xFFE2DDD5), const Color(0xFFF4F1EC)]),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        dayLabel,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isToday ? const Color(0xFFFF6A1B) : (isSelected ? const Color(0xFF1565C0) : const Color(0xFF8C867E)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Summary Stats Row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F7F4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ActivityStatTile(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: const Color(0xFFFF6A1B),
                          title: '${(selectedSteps * 0.04).round()} kcal',
                          subtitle: 'Active Burn',
                        ),
                        Container(height: 24, width: 1, color: Colors.grey.shade300),
                        _ActivityStatTile(
                          icon: Icons.place_rounded,
                          iconColor: const Color(0xFF1565C0),
                          title: '${(selectedSteps * 0.00075).toStringAsFixed(1)} km',
                          subtitle: 'Distance',
                        ),
                        Container(height: 24, width: 1, color: Colors.grey.shade300),
                        _ActivityStatTile(
                          icon: Icons.timer_rounded,
                          iconColor: const Color(0xFF2E7D32),
                          title: '${(selectedSteps * 0.008).round()} mins',
                          subtitle: 'Active Time',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ActivityStatTile extends StatelessWidget {
  const _ActivityStatTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111111),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8C867E),
          ),
        ),
      ],
    );
  }
}
