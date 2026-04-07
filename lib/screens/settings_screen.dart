import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings_model.dart';
import '../providers/settings_provider.dart';

// 디폴트값 참조용 상수 (슬라이더에 "기본값" 표시할 때 사용)
const _defaults = SettingsModel();

// ConsumerStatefulWidget: Riverpod 상태를 읽으면서 내부 State도 가지는 위젯
// - 일반 StatefulWidget에서 Riverpod을 쓰려면 이걸 써야 함
class SettingsScreen extends ConsumerStatefulWidget {
  // isFirstRun: true면 "초기 설정" 모드 (시작하기 버튼), false면 일반 설정 모드 (저장 버튼)
  final bool isFirstRun;

  const SettingsScreen({super.key, this.isFirstRun = false});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // _draft: 사용자가 슬라이더를 움직이는 동안의 임시 설정값
  // 저장 버튼을 눌러야 실제로 반영됨 (저장 전엔 provider에 영향 없음)
  late SettingsModel _draft;

  @override
  void initState() {
    super.initState();
    // 화면 열릴 때 현재 저장된 설정값을 초기값으로 불러옴
    _draft = ref.read(settingsProvider);
  }

  // 저장 버튼 눌렀을 때
  Future<void> _save() async {
    // provider에 변경된 설정 저장 (SharedPreferences에도 함께 저장됨)
    await ref.read(settingsProvider.notifier).update(_draft);

    if (widget.isFirstRun) {
      // 최초 실행 완료 표시 → 다음 실행부터 메인 화면으로 바로 진입
      await ref.read(settingsProvider.notifier).completeFirstRun();
    }

    if (mounted) {
      if (widget.isFirstRun) {
        // 초기 설정 완료 → 메인 화면으로 이동 (뒤로가기 불가)
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // 일반 설정 → 이전 화면으로 돌아가기
        Navigator.of(context).pop();
      }
    }
  }

  // 초기화 버튼: 슬라이더를 디폴트값으로 되돌림 (저장은 아직 안 된 상태)
  void _reset() {
    setState(() => _draft = const SettingsModel());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirstRun ? '초기 설정' : '설정'),
        // 최초 실행 시엔 뒤로가기 버튼 숨김
        automaticallyImplyLeading: !widget.isFirstRun,
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('초기화'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 최초 실행 시에만 안내 문구 표시
          if (widget.isFirstRun) ...[
            const Text(
              '운동 추천 기준을 설정해 주세요.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
          ],

          // 미세먼지 슬라이더 (5단위)
          _SliderTile(
            label: '미세먼지 기준 (PM2.5)',
            unit: 'μg/m³',
            value: _draft.pm25Threshold,
            defaultValue: _defaults.pm25Threshold,
            min: 10,
            max: 100,
            step: 5,
            description: '이 수치를 초과하면 야외 운동을 비추천합니다.',
            onChanged: (v) => setState(() {
              _draft = _draft.copyWith(pm25Threshold: v);
            }),
          ),
          const Divider(height: 40),

          // 기온 하한 슬라이더
          _SliderTile(
            label: '기온 하한',
            unit: '°C',
            value: _draft.tempMin,
            defaultValue: _defaults.tempMin,
            min: -10,
            max: 15,
            description: '이 온도 미만이면 야외 운동을 비추천합니다.',
            onChanged: (v) => setState(() {
              _draft = _draft.copyWith(tempMin: v);
            }),
          ),
          const Divider(height: 40),

          // 기온 상한 슬라이더
          _SliderTile(
            label: '기온 상한',
            unit: '°C',
            value: _draft.tempMax,
            defaultValue: _defaults.tempMax,
            min: 20,
            max: 40,
            description: '이 온도를 초과하면 야외 운동을 비추천합니다.',
            onChanged: (v) => setState(() {
              _draft = _draft.copyWith(tempMax: v);
            }),
          ),
          const Divider(height: 40),

          // 강수 확률 슬라이더 (5단위)
          _SliderTile(
            label: '강수 확률',
            unit: '%',
            value: _draft.rainThreshold,
            defaultValue: _defaults.rainThreshold,
            min: 10,
            max: 80,
            step: 5,
            description: '이 확률을 초과하면 야외 운동을 비추천합니다.',
            onChanged: (v) => setState(() {
              _draft = _draft.copyWith(rainThreshold: v);
            }),
          ),
          const SizedBox(height: 40),

          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(widget.isFirstRun ? '시작하기' : '저장'),
          ),
        ],
      ),
    );
  }
}

// 슬라이더 기본값 위치에 표시할 삼각형 마커를 그리는 CustomPainter
// CustomPainter: Flutter에서 캔버스에 직접 도형을 그릴 때 사용
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      // 위쪽 꼭짓점 (중앙)
      ..moveTo(size.width / 2, 0)
      // 오른쪽 아래
      ..lineTo(size.width, size.height)
      // 왼쪽 아래
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) => oldDelegate.color != color;
}

// 슬라이더 하나를 구성하는 재사용 위젯
// 라벨, 현재값, 디폴트값, 범위, 설명을 받아서 UI를 그림
class _SliderTile extends StatelessWidget {
  final String label;
  final String unit;
  final String description;
  final double value;
  final double defaultValue; // 디폴트값 (기본값 뱃지 표시용)
  final double min;
  final double max;
  final double step; // 슬라이더 단위 (기본 1단위)
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.label,
    required this.unit,
    required this.description,
    required this.value,
    required this.defaultValue,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 현재값이 디폴트값과 같으면 "기본값" 뱃지 표시
    final isDefault = value.round() == defaultValue.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                // 현재 수치 표시
                Text(
                  '${value.round()} $unit',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 디폴트값이면 "기본값" 뱃지 표시
                if (isDefault) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('기본값', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(fontSize: 13, color: Colors.grey)),

        // LayoutBuilder로 슬라이더 실제 너비를 측정해서 마커 위치 계산
        LayoutBuilder(
          builder: (context, constraints) {
            // 슬라이더 트랙의 실제 너비 (양쪽 패딩 24px씩 제외)
            const trackPadding = 24.0;
            final trackWidth = constraints.maxWidth - trackPadding * 2;

            // 기본값이 전체 범위에서 몇 % 위치인지 계산 (0.0 ~ 1.0)
            final defaultRatio = (defaultValue - min) / (max - min);

            // 마커의 x 위치 (트랙 패딩 + 비율 * 트랙 너비)
            final markerX = trackPadding + defaultRatio * trackWidth;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Slider(
                  value: value,
                  min: min,
                  max: max,
                  // divisions: 슬라이더 눈금 수 (step 단위로 움직이게)
                  divisions: ((max - min) / step).round(),
                  onChanged: onChanged,
                ),
                // 슬라이더 아래 기본값 위치에 삼각형 마커 표시
                Positioned(
                  // 슬라이더 높이(48px)만큼 아래로 내려서 트랙 바로 아래에 위치
                  top: 44,
                  left: markerX - 5, // 마커 너비(10px)의 절반만큼 왼쪽으로 보정
                  child: CustomPaint(
                    size: const Size(10, 6),
                    painter: _TrianglePainter(
                      // 현재값이 기본값이면 파란색, 아니면 회색
                      color: isDefault
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        // 슬라이더 양 끝 범위 표시
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${min.round()} $unit', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('${max.round()} $unit', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}
