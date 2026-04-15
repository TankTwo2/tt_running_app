// 기상청 API 응답 데이터 모델

// 시간대별 날씨 데이터
class WeatherData {
  final String date;         // 날짜 (yyyyMMdd)
  final int hour;            // 시간 (0~23)
  final double temperature;  // 기온 (°C)
  final int rainProbability; // 강수확률 (%)
  final String weatherType;  // 날씨 유형 (sunny/cloudy/rainy/snowy)
  final double windSpeed;    // 풍속 (m/s)

  const WeatherData({
    required this.date,
    required this.hour,
    required this.temperature,
    required this.rainProbability,
    required this.weatherType,
    required this.windSpeed,
  });
}

// 기상청 단기예보 카테고리 코드
// TMP: 기온, POP: 강수확률, PTY: 강수형태, SKY: 하늘상태, WSD: 풍속
class ForecastItem {
  final String category;  // TMP, POP, PTY, SKY, WSD 등
  final String fcstDate;  // 예보 날짜 (yyyyMMdd)
  final String fcstTime;  // 예보 시간 (HHmm)
  final String fcstValue; // 예보 값

  const ForecastItem({
    required this.category,
    required this.fcstDate,
    required this.fcstTime,
    required this.fcstValue,
  });

  factory ForecastItem.fromJson(Map<String, dynamic> json) {
    return ForecastItem(
      category: json['category'] as String,
      fcstDate: json['fcstDate'] as String,
      fcstTime: json['fcstTime'] as String,
      fcstValue: json['fcstValue'] as String,
    );
  }
}

// 강수형태 코드 → 날씨 유형 변환
// PTY: 0=없음, 1=비, 2=비/눈, 3=눈, 4=소나기
// SKY: 1=맑음, 3=구름많음, 4=흐림
String weatherTypeFromCodes({required int pty, required int sky}) {
  if (pty == 1 || pty == 4) return 'rainy'; // 비, 소나기
  if (pty == 2 || pty == 3) return 'snowy'; // 비/눈, 눈
  if (sky == 1) return 'sunny';              // 맑음
  return 'cloudy';                           // 구름많음, 흐림
}
