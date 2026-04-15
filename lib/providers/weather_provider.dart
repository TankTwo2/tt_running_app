import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weather_model.dart';
import '../models/air_quality_model.dart';
import '../models/recommendation_model.dart';
import '../services/weather_service.dart';
import '../services/air_quality_service.dart';
import 'location_provider.dart';

// 위치 없음을 나타내는 sentinel (로딩과 구분)
class NoLocationException implements Exception {
  const NoLocationException();
}

// 날씨 데이터 Provider (위치가 바뀔 때마다 자동 재조회)
final weatherProvider = FutureProvider<List<WeatherData>>((ref) async {
  final locationState = ref.watch(locationProvider);

  // 위치 없으면 로딩 유지 (never resolve) → UI에서 로딩으로 표시됨
  if (!locationState.hasLocation) throw const NoLocationException();

  return WeatherService().getForecast(
    locationState.latitude!,
    locationState.longitude!,
  );
});

// 미세먼지 데이터 Provider
final airQualityProvider = FutureProvider<AirQualityData?>((ref) async {
  final locationState = ref.watch(locationProvider);

  if (!locationState.hasLocation) throw const NoLocationException();

  return AirQualityService().getAirQuality(
    locationState.latitude!,
    locationState.longitude!,
  );
});

// 날씨 + 미세먼지 → 오늘/내일 HourlyRecommendation 리스트로 합치기
// [0] = 오늘, [1] = 내일
final recommendationProvider = FutureProvider<List<List<HourlyRecommendation>>>((ref) async {
  final locationState = ref.watch(locationProvider);

  if (!locationState.hasLocation) throw const NoLocationException();

  // airQuality는 홈스크린 PM 카드에서 별도 표시, 추천 등급 계산에 미사용
  final weatherList = await ref.watch(weatherProvider.future);

  final now = DateTime.now();
  final today = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  final tomorrow = () {
    final t = now.add(const Duration(days: 1));
    return '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}';
  }();

  List<HourlyRecommendation> toRecommendations(String date, {int minHour = 5}) {
    return weatherList
        .where((w) => w.date == date && w.hour >= minHour)
        .map((w) => HourlyRecommendation(
              hour: w.hour,
              temperature: w.temperature,
              rainProbability: w.rainProbability.toDouble(),
              weatherType: w.weatherType,
            ))
        .toList();
  }

  // 오늘은 현재 시간 이후 + 최소 5시부터, 내일은 5시부터
  final todayMinHour = now.hour < 5 ? 5 : now.hour;

  return [
    toRecommendations(today, minHour: todayMinHour),
    toRecommendations(tomorrow),
  ];
});
