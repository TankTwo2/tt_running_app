import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../models/weather_model.dart';
import '../utils/kma_grid.dart';

class WeatherService {
  static const String _baseUrl =
      'https://apihub.kma.go.kr/api/typ02/openApi/VilageFcstInfoService_2.0';

  // 단기예보 조회 (오늘 + 내일 시간대별 날씨)
  // lat, lon: 현재 위치의 위도/경도
  Future<List<WeatherData>> getForecast(double lat, double lon) async {
    final grid = KmaGrid.toGrid(lat, lon);
    final now = DateTime.now();

    // 기상청 단기예보 base_time: 0200, 0500, 0800, 1100, 1400, 1700, 2000, 2300
    // 발표 후 약 10분 뒤부터 조회 가능 → 안전하게 가장 최근 base_time 계산
    final baseTime = _getBaseTime(now);
    final baseDate = _formatDate(baseTime);
    final baseTimeStr = _formatTime(baseTime);

    final uri = Uri.parse('$_baseUrl/getVilageFcst').replace(queryParameters: {
      'authKey': kmaApiKey,
      'pageNo': '1',
      'numOfRows': '1000', // 충분히 많이 가져옴
      'dataType': 'JSON',
      'base_date': baseDate,
      'base_time': baseTimeStr,
      'nx': grid.nx.toString(),
      'ny': grid.ny.toString(),
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('기상청 API 오류: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    final items = body['response']?['body']?['items']?['item'] as List?;
    if (items == null) {
      throw Exception('기상청 API 응답 파싱 실패: ${response.body}');
    }

    // ForecastItem 리스트로 변환
    final forecasts = items.map((e) => ForecastItem.fromJson(Map<String, dynamic>.from(e))).toList();

    return _parseWeatherData(forecasts);
  }

  // ForecastItem 리스트 → 시간대별 WeatherData로 변환
  List<WeatherData> _parseWeatherData(List<ForecastItem> items) {
    // 날짜+시간별로 그룹핑
    final Map<String, Map<String, String>> grouped = {};

    for (final item in items) {
      final key = '${item.fcstDate}_${item.fcstTime}';
      grouped.putIfAbsent(key, () => {});
      grouped[key]![item.category] = item.fcstValue;
    }

    final result = <WeatherData>[];
    final now = DateTime.now();
    final today = _formatDate(now);
    final tomorrow = _formatDate(now.add(const Duration(days: 1)));

    for (final entry in grouped.entries) {
      final parts = entry.key.split('_');
      final date = parts[0];
      final time = parts[1];

      // 오늘 + 내일만 처리
      if (date != today && date != tomorrow) continue;

      final hour = int.parse(time.substring(0, 2));
      final values = entry.value;

      final tmp = double.tryParse(values['TMP'] ?? '') ?? 0.0;
      final pop = int.tryParse(values['POP'] ?? '') ?? 0;
      final pty = int.tryParse(values['PTY'] ?? '') ?? 0;
      final sky = int.tryParse(values['SKY'] ?? '') ?? 1;
      final wsd = double.tryParse(values['WSD'] ?? '') ?? 0.0;

      result.add(WeatherData(
        date: date,
        hour: hour,
        temperature: tmp,
        rainProbability: pop,
        weatherType: weatherTypeFromCodes(pty: pty, sky: sky),
        windSpeed: wsd,
      ));
    }

    // 날짜 → 시간 순 정렬
    result.sort((a, b) {
      final dateCmp = a.date.compareTo(b.date);
      return dateCmp != 0 ? dateCmp : a.hour.compareTo(b.hour);
    });
    return result;
  }

  // 기상청 base_time 계산 (발표시간 기준 가장 최근)
  DateTime _getBaseTime(DateTime now) {
    // 발표 시간 목록 (시)
    const baseTimes = [2, 5, 8, 11, 14, 17, 20, 23];

    // 현재 시간에서 10분 뒤까지 발표된 것 중 가장 최근
    final adjusted = now.subtract(const Duration(minutes: 10));

    int baseHour = baseTimes.first;
    for (final t in baseTimes) {
      if (adjusted.hour >= t) baseHour = t;
    }

    return DateTime(now.year, now.month, now.day, baseHour, 0);
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}00';
}
