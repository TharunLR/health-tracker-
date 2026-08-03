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

class _HourlyActivityCard extends StatelessWidget {
  const _HourlyActivityCard({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
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
          Text(
            '24-hour activity',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF111111),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Steps taken by hour (12 AM to 12 AM)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6F6A64),
            ),
          ),
          const SizedBox(height: 16),
          _HourlyBarChart(values: values),
        ],
      ),
    );
  }
}

class _HourlyBarChart extends StatelessWidget {
  const _HourlyBarChart({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(0, (max, value) {
      return value > max ? value : max;
    });
    final safeMax = maxValue <= 0 ? 1.0 : maxValue.toDouble();
    const minHeight = 6.0;
    const maxHeight = 110.0;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: const Color(0xFF8A8580),
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      height: 160,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(values.length, (index) {
                  final value = values[index].toDouble();
                  final height =
                      minHeight + (value / safeMax) * (maxHeight - minHeight);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      width: 24,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 14,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                value.toInt().toString(),
                                style: labelStyle,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 12,
                            height: height,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6A1B),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _HourAxisLabels(),
        ],
      ),
    );
  }
}

class _HourAxisLabels extends StatelessWidget {
  const _HourAxisLabels();

  @override
  Widget build(BuildContext context) {
    const labels = ['12am', '4am', '8am', '12pm', '4pm', '8pm', '11pm'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map(
            (label) => Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF8A8580),
              ),
            ),
          )
          .toList(),
    );
  }
}
