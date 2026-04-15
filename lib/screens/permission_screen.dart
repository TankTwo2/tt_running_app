import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/location_provider.dart';

// 최초 실행 시 위치 권한 요청 안내 화면
class PermissionScreen extends ConsumerWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // 아이콘
              const Icon(Icons.location_on, size: 80, color: Colors.blue),
              const SizedBox(height: 24),

              // 제목
              const Text(
                '위치 권한이 필요해요',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // 설명
              const Text(
                '현재 위치 기반으로 날씨와 미세먼지를 불러와\n운동하기 좋은 시간을 추천해드려요.\n\n위치 정보는 날씨 조회에만 사용됩니다.',
                style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.6),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // 허용 버튼
              ElevatedButton(
                onPressed: () async {
                  // 권한 요청 후 결과와 관계없이 설정 화면으로 이동
                  await ref.read(locationProvider.notifier).fetchCurrentLocation();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/settings-first');
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('위치 허용하기', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),

              // 나중에 버튼
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/settings-first');
                },
                child: const Text('나중에 설정할게요', style: TextStyle(color: Colors.grey)),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
