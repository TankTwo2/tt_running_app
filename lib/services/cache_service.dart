import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_model.dart';
import '../models/air_quality_model.dart';

/// 날씨·미세먼지 API 마지막 성공 데이터를 로컬에 캐시.
/// API 오류·오프라인 시 캐시를 읽어 표시한다.
class CacheService {
  static const _weatherKey = 'cache_weather_v1';
  static const _airQualityKey = 'cache_air_quality_v1';

  // ── 날씨 ──────────────────────────────────────────────────────────────────

  static Future<void> saveWeather(List<WeatherData> data) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(data.map((e) => e.toJson()).toList());
    await prefs.setString(_weatherKey, json);
  }

  /// 캐시 없으면 null 반환
  static Future<List<WeatherData>?> loadWeather() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_weatherKey);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => WeatherData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── 미세먼지 ──────────────────────────────────────────────────────────────

  static Future<void> saveAirQuality(AirQualityData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_airQualityKey, jsonEncode(data.toJson()));
  }

  /// 캐시 없으면 null 반환
  static Future<AirQualityData?> loadAirQuality() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_airQualityKey);
    if (raw == null) return null;
    return AirQualityData.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }
}
