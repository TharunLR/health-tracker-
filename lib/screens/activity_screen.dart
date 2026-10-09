import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/dashboard_snapshot.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/steps_service.dart';
import '../widgets/weekly_steps_graph_card.dart';
import 'home_screen.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({
    super.key,
    this.authService,
    this.showBottomNav = true,
  });

  final AuthService? authService;
  final bool showBottomNav;

  AuthService get _authService => authService ?? AuthService();

  static const List<BoxShadow> _softCardShadow = [
    BoxShadow(color: Color(0x12000000), blurRadius: 22, offset: Offset(0, 10)),
  ];

  Future<void> _signOut(BuildContext context) async {
    await _authService.signOut();
    if (!context.mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.splash, (route) => false);
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About'),
                  subtitle: const Text('Health Tracker app information'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('About Health Tracker'),
                        content: const Text(
                          'Health Tracker helps you stay on top of your goals, '
                          'daily activity, and progress.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Logout'),
                  subtitle: const Text('Sign out of this account'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _signOut(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your activity.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F1EC),
        elevation: 0,
        title: const Text('Activity & Workout'),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _authService.watchUserProfile(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data;
          return StreamBuilder<StepsSnapshot>(
            stream: StepsService.instance.stepsStream,
            initialData: StepsService.instance.currentSnapshot,
            builder: (context, stepsSnapshot) {
              final stepsData = stepsSnapshot.data;
              final stepsToday =
                  stepsData?.status == StepsStatus.live
                      ? stepsData?.stepsToday
                      : 0;
              final dashboard = DashboardSnapshot.fromProfile(
                fallbackName: _displayName(profile, user),
                fallbackEmail: _emailAddress(profile, user),
                profile: profile,
                stepsToday: stepsToday,
                stepsGoal: profile?.stepsGoal,
              );

              return StreamBuilder<HourlyActivitySnapshot>(
                stream: StepsService.instance.hourlyStream,
                initialData: StepsService.instance.currentHourlyActivity,
                builder: (context, hourlySnapshot) {
                  final hourlyActivity =
                      hourlySnapshot.data?.stepsPerHour ??
                          List<int>.filled(24, 0);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      const WeeklyStepsGraphCard(),
                      const SizedBox(height: 18),
                      _HourlyActivityCard(values: hourlyActivity),
                      const SizedBox(height: 18),
                      WorkoutSectionCard(workout: dashboard.workout),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: showBottomNav
          ? DashboardNavigationBar(
              currentIndex: 1,
              onHomeTap: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.home),
              onFavoritesTap: () {},
              onScanTap: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.foodLog),
              onStatsTap: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.stats),
              onSettingsTap: () => _showSettingsSheet(context),
            )
          : null,
    );
  }

  String _displayName(UserProfile? profile, User user) {
    final name = profile?.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final email = user.email ?? profile?.email ?? '';
    if (email.isEmpty || !email.contains('@')) {
      return 'there';
    }

    return email.split('@').first;
  }

  String _emailAddress(UserProfile? profile, User user) {
    final storedEmail = profile?.email.trim() ?? '';
    final email = storedEmail.isNotEmpty ? storedEmail : (user.email ?? '');
    return email.isEmpty ? 'No email saved yet.' : email;
  }
}

class _HourlyActivityCard extends StatefulWidget {
  const _HourlyActivityCard({required this.values});

  final List<int> values;

  @override
  State<_HourlyActivityCard> createState() => _HourlyActivityCardState();
}

class _HourlyActivityCardState extends State<_HourlyActivityCard> {
  int _selectedDateIndex = 29; // Today default
  final ScrollController _dateScrollController = ScrollController();
  List<int>? _historicalHourlyValues;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dateScrollController.hasClients) {
        _dateScrollController.jumpTo(_dateScrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(int index, DateTime date) async {
    setState(() {
      _selectedDateIndex = index;
    });
    if (index == 29) {
      setState(() {
        _historicalHourlyValues = null;
      });
      return;
    }
    final hourly = await StepsService.instance.getHourlyActivityForDate(date);
    if (mounted) {
      setState(() {
        _historicalHourlyValues = hourly;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days30 = List.generate(30, (i) {
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: 29 - i));
    });

    final safeIndex = _selectedDateIndex.clamp(0, 29);
    final selectedDate = days30[safeIndex];
    final isToday = safeIndex == 29;
    final dateTitle = isToday ? 'Today' : '${selectedDate.day}/${selectedDate.month}';

    final activeHourly = (isToday || _historicalHourlyValues == null)
        ? widget.values
        : _historicalHourlyValues!;

    final totalDaySteps = activeHourly.fold<int>(0, (s, v) => s + v);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: ActivityScreen._softCardShadow,
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
                      '24-Hour Activity ($dateTitle)',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFF111111),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: $totalDaySteps steps (12 AM to 12 AM)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF2E7D32),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 30-Day Horizontal Calendar Strip
          SizedBox(
            height: 38,
            child: SingleChildScrollView(
              controller: _dateScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(days30.length, (index) {
                  final date = days30[index];
                  final isSelected = index == safeIndex;
                  final isCurrentDay = index == 29;
                  final label = isCurrentDay ? 'Today' : '${date.day}/${date.month}';

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : (isCurrentDay ? const Color(0xFFFF6A1B) : const Color(0xFF6F6A64)),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFF6A1B),
                      backgroundColor: const Color(0xFFF4F1EC),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (_) => _selectDate(index, date),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _HourlyBarChart(values: activeHourly, isToday: isToday),
        ],
      ),
    );
  }
}

class _HourlyBarChart extends StatelessWidget {
  const _HourlyBarChart({required this.values, this.isToday = true});

  final List<int> values;
  final bool isToday;

  String _formatHourLabel(int hour) {
    if (hour == 0) return '12a';
    if (hour == 12) return '12p';
    if (hour < 12) return '${hour}a';
    return '${hour - 12}p';
  }

  @override
  Widget build(BuildContext context) {
    final currentHour = isToday ? DateTime.now().hour : -1;
    final maxValue = values.fold<int>(0, (max, value) {
      return value > max ? value : max;
    });
    final safeMax = maxValue <= 0 ? 100.0 : maxValue.toDouble();
    const minHeight = 8.0;
    const maxHeight = 95.0;

    return SizedBox(
      height: 150,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(24, (index) {
            final value = (index < values.length) ? values[index].toDouble() : 0.0;
            final isCurrentHour = index == currentHour;
            final height = value <= 0
                ? minHeight
                : minHeight + (value / safeMax) * (maxHeight - minHeight);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: SizedBox(
                width: 26,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (value > 0)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isCurrentHour
                                ? const Color(0xFFFF6A1B)
                                : const Color(0xFF8A8580),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isCurrentHour ? 14 : 10,
                      height: height,
                      decoration: BoxDecoration(
                        color: isCurrentHour
                            ? const Color(0xFFFF6A1B)
                            : (value > 0
                                ? const Color(0xFF2F80ED)
                                : const Color(0xFFE2DDD5)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatHourLabel(index),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
                        color: isCurrentHour
                            ? const Color(0xFFFF6A1B)
                            : const Color(0xFF8A8580),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
