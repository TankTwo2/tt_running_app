import 'package:flutter/material.dart';
import '../models/recommendation_model.dart';
import '../models/settings_model.dart';

// 시간별 운동 추천 타임라인 위젯
class TimelineWidget extends StatelessWidget {
  final List<HourlyRecommendation> recommendations;
  final SettingsModel settings;

  const TimelineWidget({super.key, required this.recommendations, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 세로 타임라인
        ListView.separated(
          shrinkWrap: true, // Column 안에서 쓰기 위해 필요
          physics: const NeverScrollableScrollPhysics(), // 바깥 스크롤에 위임
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: recommendations.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = recommendations[index];
            return _TimelineCard(item: item, settings: settings);
          },
        ),

        const SizedBox(height: 16),

        // 범례
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _LegendDot(color: _gradeColor(ExerciseGrade.good), label: '좋음'),
              const SizedBox(width: 16),
              _LegendDot(color: _gradeColor(ExerciseGrade.normal), label: '보통'),
              const SizedBox(width: 16),
              _LegendDot(color: _gradeColor(ExerciseGrade.bad), label: '나쁨'),
            ],
          ),
        ),
      ],
    );
  }
}

// 시간별 카드 위젯 (가로 행)
class _TimelineCard extends StatelessWidget {
  final HourlyRecommendation item;
  final SettingsModel settings;

  const _TimelineCard({required this.item, required this.settings});

  @override
  Widget build(BuildContext context) {
    final grade = item.grade(settings);
    final color = _gradeColor(grade);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(153), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          // 시간
          SizedBox(
            width: 52,
            child: Text(
              _shortHourLabel(item.hour),
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),

          // 날씨 아이콘
          Text(_weatherEmoji(item.weatherType), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),

          // 추천 등급 바 (세로)
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // 기온 · 강수확률 (한 줄)
          Expanded(
            child: Text(
              '${item.temperature.round()}°C · 강수 ${item.rainProbability.round()}%',
              style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),

          // 등급 텍스트
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _gradeLabel(grade),
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// 범례 점
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}


// 등급 텍스트
String _gradeLabel(ExerciseGrade grade) {
  switch (grade) {
    case ExerciseGrade.good:    return '좋음';
    case ExerciseGrade.normal: return '보통';
    case ExerciseGrade.bad:     return '나쁨';
  }
}

// 등급별 색상
Color _gradeColor(ExerciseGrade grade) {
  switch (grade) {
    case ExerciseGrade.good:    return const Color(0xFF4CAF50); // 초록
    case ExerciseGrade.normal: return const Color(0xFFFFC107); // 노랑
    case ExerciseGrade.bad:     return const Color(0xFFF44336); // 빨강
  }
}

// 짧은 시간 표시 (예: 6시, 오후2시)
String _shortHourLabel(int hour) {
  if (hour == 0) return '자정';
  if (hour == 12) return '정오';
  if (hour < 12) return '$hour시';
  return '오후${hour - 12}시';
}

// 날씨 이모지
String _weatherEmoji(String type) {
  switch (type) {
    case 'sunny':  return '☀️';
    case 'cloudy': return '☁️';
    case 'rainy':  return '🌧️';
    case 'snowy':  return '❄️';
    default:       return '☀️';
  }
}
