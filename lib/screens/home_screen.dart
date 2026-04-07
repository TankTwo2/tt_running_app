import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/location_provider.dart';
import '../providers/settings_provider.dart';
import '../models/recommendation_model.dart';
import '../widgets/timeline_widget.dart';
export '../providers/location_provider.dart' show LocationNotifier;

// 메인 화면
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);

    // 현재 표시할 위치 텍스트
    final locationText = locationState.isLoading
        ? '위치 가져오는 중...'
        : (locationState.address ?? '위치 미설정');

    return Scaffold(
      appBar: AppBar(
        // 왼쪽 위 위치 버튼
        leading: _LocationButton(
          label: locationText,
          isLoading: locationState.isLoading,
          onTap: () => _showLocationSheet(context, ref),
        ),
        leadingWidth: 260, // 위치 텍스트가 길 수 있어서 너비 확장
        actions: [
          // 오른쪽 위 설정 버튼
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: Container(
        // 임시 배경색 (나중에 Lottie로 교체)
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                TimelineWidget(
                  recommendations: generateDummyRecommendations(),
                  settings: ref.watch(settingsProvider),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 위치 선택 바텀 시트 표시
  void _showLocationSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 내용에 따라 높이 조절
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _LocationSheet(),
    );
  }
}

// 왼쪽 위 위치 버튼 위젯
class _LocationButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _LocationButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, size: 18),
            const SizedBox(width: 4),
            Flexible(
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      label,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),
      ),
    );
  }
}

// 위치 선택 바텀 시트
class _LocationSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        // 키보드가 올라올 때 가려지지 않도록
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들 바
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('위치 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // 현재 위치 버튼
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.gps_fixed),
            title: const Text('현재 위치 사용'),
            subtitle: locationState.isLoading
                ? const Text('가져오는 중...')
                : (locationState.address != null && !locationState.isManual
                    ? Text(locationState.address!)
                    : null),
            onTap: locationState.isLoading
                ? null
                : () async {
                    await ref.read(locationProvider.notifier).fetchCurrentLocation();
                    final state = ref.read(locationProvider);
                    // 권한 영구 거부 시 설정 앱 안내
                    if (state.error?.contains('영구적') == true && context.mounted) {
                      Navigator.pop(context);
                      _showPermissionDialog(context, ref);
                    } else if (state.hasLocation && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
          ),

          // 최근 위치 목록 (있을 때만 표시)
          if (locationState.recentLocations.isNotEmpty) ...[
            const Divider(),
            const Text('최근 위치', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            ...locationState.recentLocations.map(
              (recent) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(recent.address),
                onTap: () async {
                  // 저장된 좌표 그대로 사용 (재변환 없음)
                  await ref.read(locationProvider.notifier).selectRecentLocation(recent);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
          ],

          const Divider(),

          // 직접 입력 버튼
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_location_alt),
            title: const Text('직접 입력'),
            onTap: () {
              // 바텀시트 닫히기 전에 notifier를 미리 뽑아둠
              // 바텀시트가 닫히면 ref가 dispose돼서 사용 불가능해지기 때문
              final notifier = ref.read(locationProvider.notifier);
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showManualInputDialog(context, notifier);
              });
            },
          ),
        ],
      ),
    );
  }

  // 직접 입력 다이얼로그
  // notifier를 직접 받아서 dispose된 ref 문제 회피
  void _showManualInputDialog(BuildContext context, LocationNotifier notifier) {
    final controller = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('위치 직접 입력'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '예: 경기도 고양시 덕양구',
              border: const OutlineInputBorder(),
              errorText: errorText,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final address = controller.text.trim();
                if (address.isEmpty) return;

                final success = await notifier.setManualLocationByAddress(address);

                if (success && context.mounted) {
                  Navigator.pop(context);
                } else {
                  setDialogState(() => errorText = '주소를 찾지 못했습니다. 다시 입력해주세요.');
                }
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  // 위치 권한 영구 거부 시 안내 다이얼로그
  void _showPermissionDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 권한 필요'),
        content: const Text('설정에서 위치 권한을 허용해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(locationProvider.notifier).openSettings();
            },
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
  }
}
