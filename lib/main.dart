import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/settings_model.dart';
import 'models/recommendation_model.dart';
import 'providers/settings_provider.dart';
import 'screens/settings_screen.dart';
import 'screens/home_screen.dart';
import 'screens/permission_screen.dart';
import 'services/weather_service.dart';
import 'services/air_quality_service.dart';
import 'services/widget_service.dart';

// 위젯 30분 자동 갱신 시 Dart isolate에서 호출되는 백그라운드 콜백.
// Riverpod 없이 직접 서비스를 호출해 데이터를 fetch하고 위젯을 갱신한다.
@pragma('vm:entry-point')
Future<void> _widgetBackground(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();

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
    // 백그라운드 갱신 실패 시 기존 데이터 유지
  }
}

String _fmtDate(DateTime dt) =>
    '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
