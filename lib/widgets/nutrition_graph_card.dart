import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/food_log_service.dart';

class NutritionGraphCard extends StatefulWidget {
  const NutritionGraphCard({super.key});

  @override
  State<NutritionGraphCard> createState() => _NutritionGraphCardState();
}

class _NutritionGraphCardState extends State<NutritionGraphCard> {
  int _selectedDayIndex = 29; // Today default
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
    return StreamBuilder<List<FoodLogEntry>>(
      stream: FoodLogService.instance.entriesStream,
      initialData: FoodLogService.instance.currentEntries,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const [];
        final now = DateTime.now();

        final days = List.generate(30, (i) {
          return DateTime(now.year, now.month, now.day).subtract(Duration(days: 29 - i));
        });

        final dayCalories = List<double>.filled(30, 0.0);
        final dayProtein = List<double>.filled(30, 0.0);
        final dayCarbs = List<double>.filled(30, 0.0);
        final dayFat = List<double>.filled(30, 0.0);

        for (final entry in entries) {
          for (var i = 0; i < 30; i++) {
            final date = days[i];
            if (entry.timestamp.year == date.year &&
                entry.timestamp.month == date.month &&
                entry.timestamp.day == date.day) {
              final cal = entry.calories ?? 0;
              dayCalories[i] += cal;
              dayProtein[i] += entry.proteinG ?? (cal * 0.25 / 4);
              dayCarbs[i] += entry.carbsG ?? (cal * 0.50 / 4);
              dayFat[i] += entry.fatG ?? (cal * 0.25 / 9);
            }
          }
        }

        final safeIndex = _selectedDayIndex.clamp(0, 29);
        final selectedCal = dayCalories[safeIndex].round();
        final totalProtein = dayProtein[safeIndex];
        final totalCarbs = dayCarbs[safeIndex];
        final totalFat = dayFat[safeIndex];

        final maxCal = dayCalories.reduce(math.max);
        const targetCal = 2000.0;
        final highestValue = math.max(maxCal, targetCal * 1.1);

        final isTodaySelected = safeIndex == 29;
        final dateLabel = isTodaySelected
            ? 'Today'
            : '${days[safeIndex].day}/${days[safeIndex].month}';

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
                          'Nutrition Analytics (30 Days)',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF111111),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scroll horizontally to view past dates',
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
                      color: const Color(0xFFFFE9DB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFFF6A1B)),
                        const SizedBox(width: 4),
                        Text(
                          '$dateLabel: $selectedCal kcal',
                          style: const TextStyle(
                            color: Color(0xFFFF6A1B),
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

              // 30-Day Horizontal Bar Chart
              SizedBox(
                height: 165,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(30, (index) {
                      final cal = dayCalories[index];
                      final heightFactor = highestValue > 0 ? (cal / highestValue).clamp(0.05, 1.0) : 0.05;
                      final isSelected = index == safeIndex;
                      final isToday = index == 29;
                      final dayDate = days[index];
                      final dayLabel = isToday ? 'Today' : '${dayDate.day}/${dayDate.month}';

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDayIndex = index;
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
                                        color: const Color(0xFF111111),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${cal.round()}',
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
                                      colors: isSelected
                                          ? [const Color(0xFFFF6A1B), const Color(0xFFFFB37A)]
                                          : [const Color(0xFFE2DDD5), const Color(0xFFF4F1EC)],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFFF6A1B).withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : [],
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
                                      color: isToday
                                          ? const Color(0xFFFF6A1B)
                                          : (isSelected ? const Color(0xFFFF6A1B) : const Color(0xFF8C867E)),
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
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 20),

              // Macro Breakdown Section
              Text(
                'Macronutrient Breakdown ($dateLabel)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111111),
                    ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  // Donut Ring Visualizer
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: _MacroDonutPainter(
                        proteinRatio: totalProtein > 0 ? 0.3 : 0.33,
                        carbsRatio: totalCarbs > 0 ? 0.45 : 0.33,
                        fatRatio: totalFat > 0 ? 0.25 : 0.34,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Macros',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Legend items
                  Expanded(
                    child: Column(
                      children: [
                        _MacroIndicatorRow(
                          label: 'Carbs',
                          value: '${totalCarbs > 0 ? totalCarbs.round() : 145}g',
                          color: const Color(0xFFFF8A4C),
                          percent: 0.50,
                        ),
                        const SizedBox(height: 8),
                        _MacroIndicatorRow(
                          label: 'Protein',
                          value: '${totalProtein > 0 ? totalProtein.round() : 68}g',
                          color: const Color(0xFF10B981),
                          percent: 0.30,
                        ),
                        const SizedBox(height: 8),
                        _MacroIndicatorRow(
                          label: 'Fat',
                          value: '${totalFat > 0 ? totalFat.round() : 42}g',
                          color: const Color(0xFFF59E0B),
                          percent: 0.20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MacroIndicatorRow extends StatelessWidget {
  const _MacroIndicatorRow({
    required this.label,
    required this.value,
    required this.color,
    required this.percent,
  });

  final String label;
  final String value;
  final Color color;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF444444),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MacroDonutPainter extends CustomPainter {
  _MacroDonutPainter({
    required this.proteinRatio,
    required this.carbsRatio,
    required this.fatRatio,
  });

  final double proteinRatio;
  final double carbsRatio;
  final double fatRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final strokeWidth = 12.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2;

    // Carbs Segment
    final carbsSweep = 2 * math.pi * carbsRatio;
    paint.color = const Color(0xFFFF8A4C);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        carbsSweep - 0.08,
        false,
        paint);
    startAngle += carbsSweep;

    // Protein Segment
    final proteinSweep = 2 * math.pi * proteinRatio;
    paint.color = const Color(0xFF10B981);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        proteinSweep - 0.08,
        false,
        paint);
    startAngle += proteinSweep;

    // Fat Segment
    final fatSweep = 2 * math.pi * fatRatio;
    paint.color = const Color(0xFFF59E0B);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        fatSweep - 0.08,
        false,
        paint);
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) => true;
}
