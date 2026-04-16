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
    bool isFromCache = false,
  }) async {
    final todayBest = _bestTimeText(today, settings);
    final todaySummary = _summaryText(today, settings);
    final tomorrowBest = _bestTimeText(tomorrow, settings);
    final tomorrowSummary = _summaryText(tomorrow, settings);
    final todayGrade = _overallGrade(today, settings).name; // "good" / "normal" / "bad"
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final updatedAt = isFromCache ? '$timeStr 기준 (캐시)' : '$timeStr 기준';

    await Future.wait([
      HomeWidget.saveWidgetData('location', location),
      HomeWidget.saveWidgetData('today_best_time', todayBest),
      HomeWidget.saveWidgetData('today_summary', todaySummary),
      HomeWidget.saveWidgetData('today_grade', todayGrade),
      HomeWidget.saveWidgetData('tomorrow_best_time', tomorrowBest),
      HomeWidget.saveWidgetData('tomorrow_summary', tomorrowSummary),
      HomeWidget.saveWidgetData('updated_at', updatedAt),
      // 위젯 시간대 목록 — 전체 / 좋음만 (대형: PM2.5 포함)
      HomeWidget.saveWidgetData('today_slots_text', _slotsText(today, settings)),
      HomeWidget.saveWidgetData('tomorrow_slots_text', _slotsText(tomorrow, settings)),
      HomeWidget.saveWidgetData('today_slots_good_only_text', _slotsGoodOnlyText(today, settings)),
      HomeWidget.saveWidgetData('tomorrow_slots_good_only_text', _slotsGoodOnlyText(tomorrow, settings)),
      // 소형 위젯용 (PM2.5 제외 — 공간 절약)
      HomeWidget.saveWidgetData('today_slots_small_text', _slotsText(today, settings, showPm25: false)),
      HomeWidget.saveWidgetData('today_slots_good_only_small_text', _slotsGoodOnlyText(today, settings, showPm25: false)),
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

  // 운동하기 좋은 시간대 텍스트 (등급 이모지 포함)
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
      if (normalHours.isEmpty) return '🔴 야외 운동 비추';
      return '🟡 ${_hourLabel(normalHours.first)}~${_hourLabel(normalHours.last)}';
    }

    return '🟢 ${_hourLabel(goodHours.first)}~${_hourLabel(goodHours.last)}';
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

  // 오늘 대표 등급 — 좋음 > 보통 > 나쁨 순으로 최선 등급 반환
  static ExerciseGrade _overallGrade(List<HourlyRecommendation> hours, SettingsModel settings) {
    if (hours.isEmpty) return ExerciseGrade.bad;
    if (hours.any((h) => h.grade(settings) == ExerciseGrade.good)) return ExerciseGrade.good;
    if (hours.any((h) => h.grade(settings) == ExerciseGrade.normal)) return ExerciseGrade.normal;
    return ExerciseGrade.bad;
  }

  static String _hourLabel(int hour) {
    if (hour == 0) return '자정';
    if (hour == 12) return '정오';
    if (hour < 12) return '오전${hour}시';
    return '오후${hour - 12}시';
  }

  // 좋음 등급만 → 멀티라인 텍스트
  static String _slotsGoodOnlyText(
      List<HourlyRecommendation> hours, SettingsModel settings, {bool showPm25 = true}) {
    if (hours.isEmpty) return '앱을 실행해주세요';
    final good = hours.where((h) => h.grade(settings) == ExerciseGrade.good).toList();
    if (good.isEmpty) return '🔴 오늘은 좋음 시간대 없음';
    return good.map((h) {
      final label = _hourLabel(h.hour);
      final parts = <String>['${h.temperature.round()}°C', '강수 ${h.rainProbability.round()}%'];
      if (showPm25 && h.pm25 != null) parts.add('PM2.5 ${h.pm25!.round()}μg');
      return '🟢 $label  ${parts.join(' · ')}';
    }).join('\n');
  }

  // 시간대 전체 목록 → 멀티라인 텍스트 (위젯 TextView용)
  static String _slotsText(
      List<HourlyRecommendation> hours, SettingsModel settings, {bool showPm25 = true}) {
    if (hours.isEmpty) return '앱을 실행해주세요';
    return hours.map((h) {
      final g = h.grade(settings);
      final emoji = g == ExerciseGrade.good
          ? '🟢'
          : g == ExerciseGrade.normal
              ? '🟡'
              : '🔴';
      final label = _hourLabel(h.hour);
      final parts = <String>['${h.temperature.round()}°C', '강수 ${h.rainProbability.round()}%'];
      if (showPm25 && h.pm25 != null) parts.add('PM2.5 ${h.pm25!.round()}μg');
      return '$emoji $label  ${parts.join(' · ')}';
    }).join('\n');
  }
}

// 빈 시간대 sentinel (orElse용)
const _emptyHour = HourlyRecommendation(
  hour: 0,
  temperature: 0,
  rainProbability: 0,
  weatherType: 'sunny',
);
