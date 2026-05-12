import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'models/settings_model.dart';
import 'models/recommendation_model.dart';
import 'providers/settings_provider.dart';
import 'screens/settings_screen.dart';
import 'screens/home_screen.dart';
import 'screens/permission_screen.dart';
import 'services/weather_service.dart';
import 'services/air_quality_service.dart';
import 'services/widget_service.dart';

const _kWidgetRefreshTask = 'widget_refresh';

// ── 공통 데이터 fetch 및 위젯 갱신 로직 ─────────────────────────────────────

Future<void> _refreshWidgetData() async {
  final prefs = await SharedPreferences.getInstance();
  final lat = prefs.getDouble('location_lat');
  final lon = prefs.getDouble('location_lng');
  if (lat == null || lon == null) return;

  final address = prefs.getString('location_address') ?? '위치 없음';
  final settings = SettingsModel(
    pm25Threshold: prefs.getDouble('pm25Threshold') ?? 35,
    tempMin: prefs.getDouble('tempMin') ?? 5,
    tempMax: prefs.getDouble('tempMax') ?? 28,
    rainThreshold: prefs.getDouble('rainThreshold') ?? 30,
  );

  try {
    final weatherList = await WeatherService().getForecast(lat, lon);
    final airData = await AirQualityService()
        .getAirQuality(lat, lon)
        .catchError((_) => null);
    final currentPm25 = airData?.pm25;

    final now = DateTime.now();
    final today = _fmtDate(now);
    final tomorrow = _fmtDate(now.add(const Duration(days: 1)));
    final todayMinHour = now.hour < 5 ? 5 : now.hour;

    List<HourlyRecommendation> toRec(String date, {int minHour = 5, double? pm25}) =>
        weatherList
            .where((w) => w.date == date && w.hour >= minHour)
            .map((w) => HourlyRecommendation(
                  hour: w.hour,
                  temperature: w.temperature,
                  rainProbability: w.rainProbability.toDouble(),
                  weatherType: w.weatherType,
                  pm25: pm25,
                ))
            .toList();

    await WidgetService.update(
      today: toRec(today, minHour: todayMinHour, pm25: currentPm25),
      tomorrow: toRec(tomorrow),
      settings: settings,
      location: address,
    );
  } catch (_) {
    // 갱신 실패 시 기존 데이터 유지
  }
}

// ── Workmanager 백그라운드 콜백 (위젯 자동 갱신용) ──────────────────────────
// 반드시 최상위 함수 + @pragma('vm:entry-point') 필요

@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await WidgetService.init();
    await _refreshWidgetData();
    return true;
  });
}

// ── HomeWidget 백그라운드 콜백 (위젯 버튼 탭 등 인터랙션용) ─────────────────

@pragma('vm:entry-point')
Future<void> _widgetBackground(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.init();
  await _refreshWidgetData();
}

String _fmtDate(DateTime dt) =>
    '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

// ── 앱 진입점 ────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Workmanager 초기화 (백그라운드 위젯 갱신)
  await Workmanager().initialize(
    _callbackDispatcher,
    isInDebugMode: false,
  );

  // 1시간 주기 위젯 갱신 등록 (update: 앱 재실행 시 설정 갱신 반영)
  await Workmanager().registerPeriodicTask(
    'widget_hourly_update',
    _kWidgetRefreshTask,
    frequency: const Duration(hours: 1),
    constraints: Constraints(networkType: NetworkType.notRequired),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );

  HomeWidget.registerBackgroundCallback(_widgetBackground);
  await WidgetService.init();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'tt_running_app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const AppEntryPoint(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/settings-first': (context) => const SettingsScreen(isFirstRun: true),
        '/permission': (context) => const PermissionScreen(),
      },
    );
  }
}

// 최초 실행 여부에 따라 화면 분기
class AppEntryPoint extends ConsumerWidget {
  const AppEntryPoint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFirstRun = ref.watch(isFirstRunProvider);

    return isFirstRun.when(
      data: (firstRun) => firstRun
          ? const PermissionScreen()
          : const HomeScreen(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SettingsScreen(isFirstRun: true),
    );
  }
}
