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
  final double rainProbability;
  final String weatherType;
  final double? pm25; // 오늘만 채움 (현재값 기준), 내일은 null

  const HourlyRecommendation({
    required this.hour,
    required this.temperature,
    required this.rainProbability,
    required this.weatherType,
    this.pm25,
  });

  // 기온 + 강수확률 + PM2.5(오늘만) 기반 운동 추천 등급 계산
  ExerciseGrade grade(SettingsModel settings) {
    if (temperature < settings.tempMin || temperature > settings.tempMax) return ExerciseGrade.bad;
    if (rainProbability > settings.rainThreshold) return ExerciseGrade.bad;
    if (pm25 != null && pm25! > settings.pm25Threshold * 2) return ExerciseGrade.bad;

    if (pm25 != null && pm25! > settings.pm25Threshold) return ExerciseGrade.normal;
    if (rainProbability > settings.rainThreshold * 0.8) return ExerciseGrade.normal;
    if (temperature < settings.tempMin + 3 || temperature > settings.tempMax - 3) return ExerciseGrade.normal;

    return ExerciseGrade.good;
  }

  String get hourLabel {
    if (hour == 0) return '자정';
    if (hour < 12) return '오전 $hour시';
    if (hour == 12) return '정오';
    return '오후 ${hour - 12}시';
  }
}
