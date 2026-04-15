import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../models/air_quality_model.dart';

class AirQualityService {
  static const String _baseUrl =
      'https://apis.data.go.kr/B552584/ArpltnInforInqireSvc';
  static const String _stationUrl =
      'https://apis.data.go.kr/B552584/MsrstnInfoInqireSvc';

  // 가장 가까운 측정소의 실시간 미세먼지 조회
  Future<AirQualityData> getAirQuality(double lat, double lon) async {
    // 1단계: 위도/경도 → TM 좌표 변환 (에어코리아 측정소 조회에 필요)
    final (tmX, tmY) = _wgs84ToTm(lat, lon);

    // 2단계: TM 좌표 → 가장 가까운 측정소 이름
    final stationName = await _getNearestStation(tmX, tmY);

    // 3단계: 측정소 이름 → 실시간 측정값
    return await _getMeasurement(stationName);
  }

  // WGS84(위도/경도) → TM 중부원점 변환
  // 에어코리아 getNearbyMsrstnList API가 TM 좌표계 요구
  (double, double) _wgs84ToTm(double lat, double lon) {
    // GRS80 타원체 기반 TM 중부원점 파라미터
    const a = 6378137.0;          // 장반경
    const f = 1 / 298.257222101;  // 편평률
    const e2 = 2 * f - f * f;     // 이심률 제곱

    const lon0 = 127.0 * pi / 180; // 중부원점 경도 (rad)
    const lat0 = 38.0 * pi / 180;  // 중부원점 위도 (rad)
    const k0 = 1.0;                 // 축척계수
    const x0 = 200000.0;           // X 원점가산수
    const y0 = 500000.0;           // Y 원점가산수

    final latR = lat * pi / 180;
    final lonR = lon * pi / 180;

    final sinLat = sin(latR);
    final cosLat = cos(latR);
    final tanLat = tan(latR);

    final n = a / sqrt(1 - e2 * sinLat * sinLat);
    final t = tanLat * tanLat;
    final c = (e2 / (1 - e2)) * cosLat * cosLat;
    final A = cosLat * (lonR - lon0);

    // 자오선호 계산
    double meridianArc(double r) {
      return a * ((1 - e2 / 4 - 3 * e2 * e2 / 64) * r
          - (3 * e2 / 8 + 3 * e2 * e2 / 32) * sin(2 * r)
          + (15 * e2 * e2 / 256) * sin(4 * r));
    }

    final m = meridianArc(latR);
    final m0 = meridianArc(lat0);

    final x = x0 + k0 * n * (A
        + (1 - t + c) * pow(A, 3) / 6
        + (5 - 18 * t + t * t + 72 * c - 58 * (e2 / (1 - e2))) * pow(A, 5) / 120);

    final y = y0 + k0 * (m - m0 + n * tanLat * (
        pow(A, 2) / 2
        + (5 - t + 9 * c + 4 * c * c) * pow(A, 4) / 24
        + (61 - 58 * t + t * t) * pow(A, 6) / 720));

    return (x, y);
  }

  // TM 좌표 기반 가장 가까운 측정소 이름 조회
  Future<String> _getNearestStation(double tmX, double tmY) async {
    // serviceKey는 URL에 직접 삽입 (replace 사용 시 이중 인코딩 방지)
    final uri = Uri.parse(
      '$_stationUrl/getNearbyMsrstnList'
      '?serviceKey=$airKoreaApiKey'
      '&returnType=json'
      '&tmX=${tmX.toStringAsFixed(2)}'
      '&tmY=${tmY.toStringAsFixed(2)}'
      '&ver=1.1',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('측정소 조회 오류: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    final items = body['response']?['body']?['items'] as List?;
    if (items == null || items.isEmpty) {
      throw Exception('근처 측정소를 찾지 못했습니다.');
    }

    final name = items.first['stationName']?.toString() ?? '';
    if (name.isEmpty) throw Exception('측정소 이름이 비어있습니다.');
    return name;
  }

  // 측정소별 실시간 미세먼지 조회
  Future<AirQualityData> _getMeasurement(String stationName) async {
    final encodedStation = Uri.encodeComponent(stationName);
    final uri = Uri.parse(
      '$_baseUrl/getMsrstnAcctoRltmMesureDnsty'
      '?serviceKey=$airKoreaApiKey'
      '&returnType=json'
      '&numOfRows=1'
      '&pageNo=1'
      '&stationName=$encodedStation'
      '&dataTerm=DAILY'
      '&ver=1.0',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('미세먼지 측정값 조회 오류: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    final items = body['response']?['body']?['items'] as List?;
    if (items == null || items.isEmpty) {
      throw Exception('미세먼지 데이터가 없습니다. 측정소: $stationName');
    }

    return AirQualityData.fromJson(Map<String, dynamic>.from(items.first));
  }
}
