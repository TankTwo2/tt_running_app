import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weather_model.dart';
import '../models/air_quality_model.dart';
import '../models/recommendation_model.dart';
import '../services/weather_service.dart';
import '../services/air_quality_service.dart';
import '../services/cache_service.dart';
import '../services/widget_service.dart';
import 'location_provider.dart';
import 'settings_provider.dart';

// 위치 없음을 나타내는 sentinel (로딩과 구분)
class NoLocationException implements Exception {
  const NoLocationException();
}

/// 현재 날씨 데이터가 캐시에서 온 것인지 여부.
/// weatherProvider가 API 실패 후 캐시를 사용하면 true로 변경.
final isWeatherCachedProvider = StateProvider<bool>((ref) => false);

// 날씨 데이터 Provider — API 실패 시 캐시 폴백
final weatherProvider = FutureProvider<List<WeatherData>>((ref) async {
  final locationState = ref.watch(locationProvider);

  if (!locationState.hasLocation) throw const NoLocationException();

  try {
    final data = await WeatherService().getForecast(
      locationState.latitude!,
      locationState.longitude!,
    );
    await CacheService.saveWeather(data);
    // ref.read: FutureProvider 내에서 다른 provider 상태 변경 (side effect)
    ref.read(isWeatherCachedProvider.notifier).state = false;
    return data;
  } catch (_) {
    final cached = await CacheService.loadWeather();
    if (cached != null && cached.isNotEmpty) {
      ref.read(isWeatherCachedProvider.notifier).state = true;
      return cached;
    }
    ref.read(isWeatherCachedProvider.notifier).state = false;
    rethrow;
  }
});

// 미세먼지 데이터 Provider — API 실패 시 캐시 폴백 (에어코리아 실패는 허용)
final airQualityProvider = FutureProvider<AirQualityData?>((ref) async {
  final locationState = ref.watch(locationProvider);

  if (!locationState.hasLocation) throw const NoLocationException();

  try {
    final data = await AirQualityService().getAirQuality(
      locationState.latitude!,
      locationState.longitude!,
    );
    if (data != null) await CacheService.saveAirQuality(data);
    return data;
  } catch (_) {
    // 에어코리아 실패 → 캐시 시도, 없으면 null (추천 엔진이 PM 없이 동작)
    return CacheService.loadAirQuality();
  }
});

// 날씨 + 미세먼지 → 오늘/내일 HourlyRecommendation 리스트로 합치기
// [0] = 오늘, [1] = 내일
final recommendationProvider = FutureProvider<List<List<HourlyRecommendation>>>((ref) async {
  final locationState = ref.watch(locationProvider);

  if (!locationState.hasLocation) throw const NoLocationException();

  final weatherList = await ref.watch(weatherProvider.future);

  // PM2.5: 현재값만 있으므로 오늘 추천에만 반영, 내일은 null
  // 에어코리아 실패해도 날씨 추천은 정상 표시 (pm25 = null로 처리)
  final airData = await ref.watch(airQualityProvider.future).catchError((_) => null);
  final currentPm25 = airData?.pm25;

  final now = DateTime.now();
  final today = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  final tomorrow = () {
    final t = now.add(const Duration(days: 1));
    return '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}';
  }();

  List<HourlyRecommendation> toRecommendations(String date, {int minHour = 5, double? pm25}) {
    return weatherList
        .where((w) => w.date == date && w.hour >= minHour)
        .map((w) => HourlyRecommendation(
              hour: w.hour,
              temperature: w.temperature,
              rainProbability: w.rainProbability.toDouble(),
              weatherType: w.weatherType,
              pm25: pm25,
            ))
        .toList();
  }

  // 오늘은 현재 시간 이후 + 최소 5시부터 + PM2.5 반영, 내일은 5시부터 PM 없음
  final todayMinHour = now.hour < 5 ? 5 : now.hour;

  final todayList = toRecommendations(today, minHour: todayMinHour, pm25: currentPm25);
  final tomorrowList = toRecommendations(tomorrow);

  // 위젯 데이터 갱신 (에러 나도 추천 데이터는 정상 반환)
  final settings = ref.read(settingsProvider);
  final isCached = ref.read(isWeatherCachedProvider);
  WidgetService.update(
    today: todayList,
    tomorrow: tomorrowList,
    settings: settings,
    location: locationState.address ?? '위치 없음',
    isFromCache: isCached,
  ).ignore();

  return [todayList, tomorrowList];
});
