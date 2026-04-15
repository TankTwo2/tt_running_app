import 'settings_model.dart';

// 운동 추천 등급
enum ExerciseGrade {
  good,   // 좋음 (초록)
  normal, // 보통 (노랑)
  bad,    // 나쁨 (빨강)
}

// 시간대별 운동 추천 데이터 (PM은 별도 표시, 여기선 기온+강수만)
class HourlyRecommendation {
  final int hour;
  final double temperature;
  final double rainProbability;
  final String weatherType;

  const HourlyRecommendation({
    required this.hour,
    required this.temperature,
    required this.rainProbability,
    required this.weatherType,
  });

  // 기온 + 강수확률 기반 운동 추천 등급 계산 (PM 제외)
  ExerciseGrade grade(SettingsModel settings) {
    if (temperature < settings.tempMin || temperature > settings.tempMax) return ExerciseGrade.bad;
    if (rainProbability > settings.rainThreshold) return ExerciseGrade.bad;

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
