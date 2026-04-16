// 에어코리아 API 응답 데이터 모델

// 현재 미세먼지 측정값
class AirQualityData {
  final double pm25; // 초미세먼지 PM2.5 (μg/m³)
  final double pm10; // 미세먼지 PM10 (μg/m³)
  final String grade; // 통합대기환경지수 등급 (1=좋음, 2=보통, 3=나쁨, 4=매우나쁨)
  final String stationName; // 측정소 이름
  final String dataTime;    // 측정 시간

  const AirQualityData({
    required this.pm25,
    required this.pm10,
    required this.grade,
    required this.stationName,
    required this.dataTime,
  });

  Map<String, dynamic> toJson() => {
    'pm25Value': pm25.toString(),
    'pm10Value': pm10.toString(),
    'khaiGrade': grade,
    'stationName': stationName,
    'dataTime': dataTime,
  };

  factory AirQualityData.fromJson(Map<String, dynamic> json) {
    // API에서 '-' (미측정) 오거나 null일 수 있어서 안전하게 파싱
    return AirQualityData(
      pm25: _parseDouble(json['pm25Value']),
      pm10: _parseDouble(json['pm10Value']),
      grade: json['khaiGrade']?.toString() ?? '1',
      stationName: json['stationName']?.toString() ?? '',
      dataTime: json['dataTime']?.toString() ?? '',
    );
  }
}

// 문자열 → double 변환 (미측정 '-' 등 예외 처리)
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  final str = value.toString().trim();
  if (str == '-' || str.isEmpty) return 0.0;
  return double.tryParse(str) ?? 0.0;
}
