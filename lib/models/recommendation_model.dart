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
  // PM2.5와 날씨 각각 등급을 내고, 더 나쁜 쪽을 최종 등급으로 사용
  ExerciseGrade grade(SettingsModel settings) {
    final pm25Grade = _pm25Grade(settings);
    final weatherGrade = _weatherGrade(settings);
    // enum index: good=0, normal=1, bad=2 → 높을수록 나쁨
    return pm25Grade.index >= weatherGrade.index ? pm25Grade : weatherGrade;
  }

  // PM2.5 단독 등급 (좋음 ≤15, 보통 16~threshold, 나쁨 >threshold)
  ExerciseGrade _pm25Grade(SettingsModel settings) {
    if (pm25 == null) return ExerciseGrade.good; // 내일은 PM 없음 → 제한 없음
    if (pm25! > settings.pm25Threshold) return ExerciseGrade.bad;   // 나쁨/매우나쁨
    if (pm25! > 15) return ExerciseGrade.normal;                     // 보통
    return ExerciseGrade.good;                                        // 좋음
  }

  // 날씨 단독 등급 (기온·강수 기반)
  ExerciseGrade _weatherGrade(SettingsModel settings) {
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
