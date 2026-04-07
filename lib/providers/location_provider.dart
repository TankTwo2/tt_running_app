import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';

// 위치 상태를 나타내는 클래스
class LocationState {
  final double? latitude;   // 위도
  final double? longitude;  // 경도
  final String? address;    // 표시용 주소 (수동 설정 시 사용)
  final bool isManual;      // true면 수동 설정, false면 GPS 자동
  final bool isLoading;
  final String? error;

  const LocationState({
    this.latitude,
    this.longitude,
    this.address,
    this.isManual = false,
    this.isLoading = false,
    this.error,
  });

  bool get hasLocation => latitude != null && longitude != null;

  LocationState copyWith({
    double? latitude,
    double? longitude,
    String? address,
    bool? isManual,
    bool? isLoading,
    String? error,
  }) {
    return LocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      isManual: isManual ?? this.isManual,
      isLoading: isLoading ?? this.isLoading,
      error: error,  // error는 null로 초기화 가능하도록 ?? 미사용
    );
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier(),
);

class LocationNotifier extends StateNotifier<LocationState> {
  final _service = LocationService();

  LocationNotifier() : super(const LocationState()) {
    _loadSaved(); // 앱 시작 시 저장된 위치 불러오기
  }

  // 저장된 위치 불러오기 (수동 설정했던 위치가 있으면 복원)
  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('location_lat');
    final lng = prefs.getDouble('location_lng');
    final address = prefs.getString('location_address');
    final isManual = prefs.getBool('location_is_manual') ?? false;

    if (lat != null && lng != null) {
      state = LocationState(
        latitude: lat,
        longitude: lng,
        address: address,
        isManual: isManual,
      );
    }
  }

  // GPS로 현재 위치 가져오기
  Future<void> fetchCurrentLocation() async {
    state = state.copyWith(isLoading: true);

    final result = await _service.getCurrentLocation();

    if (result.isSuccess) {
      final pos = result.position!;
      // 주소 변환 성공 시 새 주소 사용, 실패 시 기존 주소 유지
      final address = result.address ?? state.address;
      state = LocationState(
        latitude: pos.latitude,
        longitude: pos.longitude,
        address: address,
        isManual: false,
        isLoading: false,
      );
      // SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('location_lat', pos.latitude);
      await prefs.setDouble('location_lng', pos.longitude);
      if (address != null) {
        await prefs.setString('location_address', address);
      }
      await prefs.setBool('location_is_manual', false);
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
    }
  }

  // 수동으로 위치 설정 (위도/경도 + 표시용 주소)
  Future<void> setManualLocation({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    state = LocationState(
      latitude: latitude,
      longitude: longitude,
      address: address,
      isManual: true,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('location_lat', latitude);
    await prefs.setDouble('location_lng', longitude);
    await prefs.setString('location_address', address);
    await prefs.setBool('location_is_manual', true);
  }

  // 주소 텍스트 → 좌표 변환 후 저장 (수동 입력용)
  // 성공 시 true, 주소를 찾지 못하면 false 반환
  Future<bool> setManualLocationByAddress(String inputAddress) async {
    try {
      // locationFromAddress: 주소 문자열 → 위도/경도 변환
      final locations = await locationFromAddress(inputAddress);
      if (locations.isEmpty) return false;

      final loc = locations.first;
      // 좌표로 다시 정제된 주소 가져오기 (동까지 표시)
      final resolvedAddress = await _service.coordsToAddress(loc.latitude, loc.longitude);

      await setManualLocation(
        latitude: loc.latitude,
        longitude: loc.longitude,
        address: resolvedAddress ?? inputAddress, // 변환 실패 시 입력값 그대로
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // 권한 앱 설정 열기
  Future<void> openSettings() => _service.openAppSettings();

  // 권한 상태 확인
  Future<LocationPermission> checkPermission() => _service.checkPermission();
}
