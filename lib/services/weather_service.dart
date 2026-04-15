import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
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
    // 서버 오류/타임아웃 시 이전 base_time으로 최대 2회 재시도
    Exception? lastError;
    for (int attempt = 0; attempt < 3; attempt++) {
      final baseTime = _getBaseTime(now, backStep: attempt);
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

      // 기상청 apihub의 TLS 중간 인증서 문제 우회 (정부 API 공통 이슈)
      final dartClient = HttpClient();
      dartClient.badCertificateCallback = (cert, host, port) => true;
      dartClient.connectionTimeout = const Duration(seconds: 10);
      final client = IOClient(dartClient);

      try {
        final response = await client.get(uri, headers: {
          'Connection': 'close',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14)',
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 25));

        if (response.statusCode == 500) {
          lastError = Exception('기상청 서버 오류 (500)');
          continue; // 이전 base_time으로 재시도
        }
        if (response.statusCode != 200) {
          throw Exception('기상청 API 오류: ${response.statusCode}');
        }

        final body = jsonDecode(response.body);
        final items = body['response']?['body']?['items']?['item'] as List?;
        if (items == null) {
          lastError = Exception('기상청 API 응답 파싱 실패');
          continue;
        }

        // ForecastItem 리스트로 변환
        final forecasts = items.map((e) => ForecastItem.fromJson(Map<String, dynamic>.from(e))).toList();
        return _parseWeatherData(forecasts);
      } on TimeoutException {
        lastError = TimeoutException('기상청 서버 응답 없음');
        continue;
      } on SocketException catch (e) {
        lastError = Exception('기상청 연결 실패: $e');
        continue;
      } finally {
        client.close();
      }
    }
    throw lastError ?? Exception('날씨 데이터를 불러오지 못했습니다.');
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
  // backStep: 0 = 최신, 1 = 한 단계 이전 (500 오류 시 재시도용)
  DateTime _getBaseTime(DateTime now, {int backStep = 0}) {
    // 발표 시간 목록 (시) — 하루 전 23시도 포함해 자정 이후 처리
    const baseTimes = [2, 5, 8, 11, 14, 17, 20, 23];

    // 현재 시간에서 10분 전까지 발표된 것 중 가장 최근
    final adjusted = now.subtract(const Duration(minutes: 10));

    // 오늘 중 가장 최근 발표 시간 탐색
    int? baseHour;
    for (final t in baseTimes) {
      if (adjusted.hour >= t) baseHour = t;
    }

    // 자정~02:09: 전날 23시 데이터 사용
    if (baseHour == null) {
      final yesterday = now.subtract(const Duration(days: 1));
      final steps = backStep + 1; // 23, 20, 17, ... 순으로 거슬러 올라감
      final hour = baseTimes[baseTimes.length - steps.clamp(1, baseTimes.length)];
      return DateTime(yesterday.year, yesterday.month, yesterday.day, hour, 0);
    }

    // backStep만큼 이전 발표 시간으로 이동
    if (backStep > 0) {
      final idx = baseTimes.indexOf(baseHour);
      if (idx > 0) {
        return DateTime(now.year, now.month, now.day, baseTimes[idx - backStep.clamp(0, idx)], 0);
      }
      // 오늘 첫 번째 발표(02시) 이전이면 전날 23시
      final yesterday = now.subtract(const Duration(days: 1));
      return DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 0);
    }

    return DateTime(now.year, now.month, now.day, baseHour, 0);
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}00';
}
