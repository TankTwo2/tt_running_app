import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/weather_provider.dart';

// 현재 미세먼지 수치 카드 (상단 고정)
class PmCard extends ConsumerWidget {
  const PmCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airAsync = ref.watch(airQualityProvider);

    return airAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (airData) {
        if (airData == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(40), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.air, color: Colors.white70, size: 20),
                const SizedBox(width: 10),
                const Text('현재 미세먼지', style: TextStyle(fontSize: 11, color: Colors.white54)),
                const Spacer(),
                _PmBadge(label: 'PM2.5(초미세)', value: airData.pm25, isPm25: true),
                const SizedBox(width: 10),
                _PmBadge(label: 'PM10(미세)', value: airData.pm10, isPm25: false),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 개별 PM 배지 (라벨 + 수치 + 등급)
class _PmBadge extends StatelessWidget {
  final String label;
  final double value;
  final bool isPm25; // PM2.5와 PM10 기준이 다름

  const _PmBadge({required this.label, required this.value, required this.isPm25});

  @override
  Widget build(BuildContext context) {
    final (grade, color) = isPm25 ? _pm25Grade(value) : _pm10Grade(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              '${value.round()}μg',
              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(50),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(grade, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}

// PM2.5 기준 등급 (μg/m³)
(String, Color) _pm25Grade(double v) {
  if (v <= 15) return ('좋음', const Color(0xFF4CAF50));
  if (v <= 35) return ('보통', const Color(0xFFFFC107));
  if (v <= 75) return ('나쁨', const Color(0xFFFF7043));
  return ('매우나쁨', const Color(0xFFF44336));
}

// PM10 기준 등급 (μg/m³)
(String, Color) _pm10Grade(double v) {
  if (v <= 30) return ('좋음', const Color(0xFF4CAF50));
  if (v <= 80) return ('보통', const Color(0xFFFFC107));
  if (v <= 150) return ('나쁨', const Color(0xFFFF7043));
  return ('매우나쁨', const Color(0xFFF44336));
}
