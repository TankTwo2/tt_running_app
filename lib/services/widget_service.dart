import 'package:home_widget/home_widget.dart';
import '../models/recommendation_model.dart';
import '../models/settings_model.dart';

const String _appGroupId = 'com.example.tt_running_app';
const String _iOSWidgetName = 'RunningWidget'; // iOS 대비 (현재 Android 타겟)

class WidgetService {
  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  // 추천 데이터 → 위젯에 저장 후 갱신 요청
  static Future<void> update({
    required List<HourlyRecommendation> today,
    required List<HourlyRecommendation> tomorrow,
    required SettingsModel settings,
    required String location,
  }) async {
    final todayBest = _bestTimeText(today, settings);
    final todaySummary = _summaryText(today, settings);
    final tomorrowBest = _bestTimeText(tomorrow, settings);
    final tomorrowSummary = _summaryText(tomorrow, settings);
    final now = DateTime.now();
    final updatedAt = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} 기준';

    await Future.wait([
      HomeWidget.saveWidgetData('location', location),
      HomeWidget.saveWidgetData('today_best_time', todayBest),
      HomeWidget.saveWidgetData('today_summary', todaySummary),
      HomeWidget.saveWidgetData('tomorrow_best_time', tomorrowBest),
      HomeWidget.saveWidgetData('tomorrow_summary', tomorrowSummary),
      HomeWidget.saveWidgetData('updated_at', updatedAt),
      // 백그라운드 갱신 루프 방지용 타임스탬프
      HomeWidget.saveWidgetData('widget_refreshed_at', now.millisecondsSinceEpoch),
    ]);

    await HomeWidget.updateWidget(
      iOSName: _iOSWidgetName,
      androidName: 'SmallRunningWidget',
    );
    await HomeWidget.updateWidget(
      iOSName: _iOSWidgetName,
      androidName: 'LargeRunningWidget',
    );
  }

  // 운동하기 좋은 시간대 텍스트 (good인 시간만 모아서 범위로 표시)
  static String _bestTimeText(List<HourlyRecommendation> hours, SettingsModel settings) {
    final goodHours = hours
        .where((h) => h.grade(settings) == ExerciseGrade.good)
        .map((h) => h.hour)
        .toList();

    if (goodHours.isEmpty) {
      final normalHours = hours
          .where((h) => h.grade(settings) == ExerciseGrade.normal)
          .map((h) => h.hour)
          .toList();
      if (normalHours.isEmpty) return '오늘은 야외 운동 비추';
      return '${_hourLabel(normalHours.first)}~${_hourLabel(normalHours.last)} (보통)';
    }

    return '${_hourLabel(goodHours.first)}~${_hourLabel(goodHours.last)} 추천';
  }

  // 기온/강수 요약 (첫 번째 good 시간대 기준)
  static String _summaryText(List<HourlyRecommendation> hours, SettingsModel settings) {
    final best = hours.firstWhere(
      (h) => h.grade(settings) == ExerciseGrade.good,
      orElse: () => hours.isNotEmpty ? hours.first : _emptyHour,
    );

    if (hours.isEmpty) return '';

    final parts = <String>[];
    parts.add('${best.temperature.round()}°C');
    parts.add('강수 ${best.rainProbability.round()}%');
    if (best.pm25 != null) parts.add('PM2.5 ${best.pm25!.round()}μg');

    return parts.join(' · ');
  }

  static String _hourLabel(int hour) {
    if (hour == 0) return '자정';
    if (hour == 12) return '정오';
    if (hour < 12) return '오전${hour}시';
    return '오후${hour - 12}시';
  }
}

// 빈 시간대 sentinel (orElse용)
const _emptyHour = HourlyRecommendation(
  hour: 0,
  temperature: 0,
  rainProbability: 0,
  weatherType: 'sunny',
);
