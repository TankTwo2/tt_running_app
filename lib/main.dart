import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/settings_provider.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'tt_running_app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const AppEntryPoint(),
      routes: {
        '/home': (context) => const HomeStub(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

// 메인 화면 임시 stub (나중에 별도 파일로 분리 예정)
class HomeStub extends StatelessWidget {
  const HomeStub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 운동 추천'),
        actions: [
          // 설정 버튼: 설정 화면으로 이동
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: const Center(child: Text('메인 화면 (준비 중)')),
    );
  }
}

// 최초 실행 여부에 따라 화면 분기
class AppEntryPoint extends ConsumerWidget {
  const AppEntryPoint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFirstRun = ref.watch(isFirstRunProvider);

    return isFirstRun.when(
      data: (firstRun) => firstRun
          ? const SettingsScreen(isFirstRun: true)
          : const HomeStub(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SettingsScreen(isFirstRun: true),
    );
  }
}
