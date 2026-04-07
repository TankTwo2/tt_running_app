import 'settings_model.dart';

// 운동 추천 등급
enum ExerciseGrade {
  good,   // 좋음 (초록)
  normal, // 보통 (노랑)
  bad,    // 나쁨 (빨강)
}

// 시간대별 운동 추천 데이터
class HourlyRecommendation {
  final int hour;
  final double temperature;
  final double pm25;
  final double rainProbability;
  final String weatherType;

  const HourlyRecommendation({
    required this.hour,
    required this.temperature,
    required this.pm25,
    required this.rainProbability,
    required this.weatherType,
  });

  // 설정값 기반으로 등급 자동 계산
  ExerciseGrade grade(SettingsModel settings) {
    // 나쁨: 사용자 설정 기준 초과 시
    if (pm25 > settings.pm25Threshold) return ExerciseGrade.bad;
    if (temperature < settings.tempMin || temperature > settings.tempMax) return ExerciseGrade.bad;
    if (rainProbability > settings.rainThreshold) return ExerciseGrade.bad;

    // 보통: 기준의 80% 이상 근접 시 (살짝 여유 있는 상태)
    if (pm25 > settings.pm25Threshold * 0.8) return ExerciseGrade.normal;
    if (rainProbability > settings.rainThreshold * 0.8) return ExerciseGrade.normal;
    if (temperature < settings.tempMin + 3 || temperature > settings.tempMax - 3) return ExerciseGrade.normal;

    return ExerciseGrade.good;
  }

  // 표시용 시간 문자열
  String get hourLabel {
    if (hour == 0) return '자정';
    if (hour < 12) return '오전 $hour시';
    if (hour == 12) return '정오';
    return '오후 ${hour - 12}시';
  }
}

// 더미 데이터 생성 (grade는 수치로 자동 계산되므로 제거)
List<HourlyRecommendation> generateDummyRecommendations() {
  return [
    HourlyRecommendation(hour: 5,  temperature: 16, pm25: 10, rainProbability: 5,  weatherType: 'sunny'),
    HourlyRecommendation(hour: 6,  temperature: 18, pm25: 12, rainProbability: 5,  weatherType: 'sunny'),
    HourlyRecommendation(hour: 7,  temperature: 19, pm25: 14, rainProbability: 5,  weatherType: 'sunny'),
    HourlyRecommendation(hour: 8,  temperature: 21, pm25: 18, rainProbability: 10, weatherType: 'sunny'),
    HourlyRecommendation(hour: 9,  temperature: 23, pm25: 28, rainProbability: 10, weatherType: 'cloudy'),
    HourlyRecommendation(hour: 10, temperature: 25, pm25: 32, rainProbability: 20, weatherType: 'cloudy'),
    HourlyRecommendation(hour: 11, temperature: 27, pm25: 40, rainProbability: 30, weatherType: 'cloudy'),
    HourlyRecommendation(hour: 12, temperature: 22, pm25: 12, rainProbability: 70, weatherType: 'rainy'),
    HourlyRecommendation(hour: 13, temperature: 21, pm25: 10, rainProbability: 80, weatherType: 'rainy'),
    HourlyRecommendation(hour: 14, temperature: 20, pm25: 11, rainProbability: 65, weatherType: 'rainy'),
    HourlyRecommendation(hour: 15, temperature: 27, pm25: 30, rainProbability: 25, weatherType: 'cloudy'),
    HourlyRecommendation(hour: 16, temperature: 25, pm25: 25, rainProbability: 15, weatherType: 'cloudy'),
    HourlyRecommendation(hour: 17, temperature: 23, pm25: 20, rainProbability: 10, weatherType: 'sunny'),
    HourlyRecommendation(hour: 18, temperature: 21, pm25: 16, rainProbability: 5,  weatherType: 'sunny'),
    HourlyRecommendation(hour: 19, temperature: 20, pm25: 14, rainProbability: 5,  weatherType: 'sunny'),
    HourlyRecommendation(hour: 20, temperature: 19, pm25: 12, rainProbability: 5,  weatherType: 'sunny'),
    HourlyRecommendation(hour: 21, temperature: 18, pm25: 22, rainProbability: 10, weatherType: 'cloudy'),
    HourlyRecommendation(hour: 22, temperature: 17, pm25: 20, rainProbability: 10, weatherType: 'cloudy'),
    HourlyRecommendation(hour: 23, temperature: 16, pm25: 18, rainProbability: 5,  weatherType: 'cloudy'),
    HourlyRecommendation(hour: 24, temperature: 15, pm25: 15, rainProbability: 5,  weatherType: 'cloudy'),
  ];
}
