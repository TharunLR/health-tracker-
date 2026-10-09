import 'dart:async';

import 'package:flutter/material.dart';

import '../services/dashboard_tab_controller.dart';
import '../services/esp32_health_band_service.dart';
import '../services/steps_service.dart';
import 'activity_screen.dart';
import 'food_scanner_screen.dart';
import 'home_screen.dart';
import 'stats_screen.dart';
import 'wellness_screen.dart';
import '../widgets/calz_ai_coach_sheet.dart';
import '../widgets/calz_mascot_widget.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell>
    with WidgetsBindingObserver {
  StreamSubscription<HealthBandData>? _bandSub;
  bool? _lastConnectionState;

  final List<Widget> _tabs = const [
    HomeScreen(showBottomNav: false),
    ActivityScreen(showBottomNav: false),
    FoodScannerScreen(),
    StatsScreen(showBottomNav: false),
    WellnessScreen(showBottomNav: false),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final safeIndex = widget.initialIndex.clamp(0, _tabs.length - 1);
    DashboardTabController.setIndex(safeIndex);
    unawaited(StepsService.instance.start());

    // Show initial popup message when app opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isConnected = ESP32HealthBandService.instance.currentData.isConnected;
      _lastConnectionState = isConnected;
      _showBandStatusToast(isConnected);
    });

    // Listen for state changes
    _bandSub = ESP32HealthBandService.instance.dataStream.listen((data) {
      if (_lastConnectionState != data.isConnected) {
        _lastConnectionState = data.isConnected;
        _showBandStatusToast(data.isConnected);
      }
    });
  }

  void _showBandStatusToast(bool isConnected) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isConnected ? Icons.check_circle_rounded : Icons.watch_off_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                isConnected ? 'Band Connected' : 'Band Disconnected',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: isConnected ? Colors.teal.shade800 : Colors.blueGrey.shade900,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  @override
  void dispose() {
    _bandSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(StepsService.instance.refreshFromStorage());
      final isConnected = ESP32HealthBandService.instance.currentData.isConnected;
      _showBandStatusToast(isConnected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: DashboardTabController.indexNotifier,
      builder: (context, index, _) {
        final safeIndex = index.clamp(0, _tabs.length - 1);
        if (safeIndex != index) {
          DashboardTabController.setIndex(safeIndex);
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF4F1EC),
          body: IndexedStack(index: safeIndex, children: _tabs),
          floatingActionButton: Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: FloatingActionButton.extended(
              onPressed: () => CalzAICoachSheet.show(context),
              backgroundColor: const Color(0xFFFF7A59),
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              icon: const SizedBox(
                width: 28,
                height: 28,
                child: CalzMascotWidget(size: 28, showBadge: false),
              ),
              label: const Text(
                'Ask ARTI AI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: DashboardNavigationBar(
            currentIndex: safeIndex,
            onHomeTap: () => DashboardTabController.setIndex(0),
            onFavoritesTap: () => DashboardTabController.setIndex(1),
            onScanTap: () => DashboardTabController.setIndex(2),
            onStatsTap: () => DashboardTabController.setIndex(3),
            onSettingsTap: () => DashboardTabController.setIndex(4),
          ),
        );
      },
    );
  }
}
