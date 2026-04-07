import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';

// 최근 위치 항목 (주소 + 좌표 함께 저장)
class RecentLocation {
  final String address;
  final double latitude;
  final double longitude;

  const RecentLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  // SharedPreferences 저장을 위해 Map으로 변환
  Map<String, dynamic> toMap() => {
        'address': address,
        'lat': latitude,
        'lng': longitude,
      };

  factory RecentLocation.fromMap(Map<String, dynamic> map) => RecentLocation(
        address: map['address'] as String,
        latitude: map['lat'] as double,
        longitude: map['lng'] as double,
      );
}

// 위치 상태를 나타내는 클래스
class LocationState {
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool isManual;
  final bool isLoading;
  final String? error;
  final List<RecentLocation> recentLocations; // 최근 위치 히스토리 (최대 5개)

  const LocationState({
    this.latitude,
    this.longitude,
    this.address,
    this.isManual = false,
    this.isLoading = false,
    this.error,
    this.recentLocations = const [],
  });

  bool get hasLocation => latitude != null && longitude != null;

  LocationState copyWith({
    double? latitude,
    double? longitude,
    String? address,
    bool? isManual,
    bool? isLoading,
    String? error,
    List<RecentLocation>? recentLocations,
  }) {
    return LocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      isManual: isManual ?? this.isManual,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      recentLocations: recentLocations ?? this.recentLocations,
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
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('location_lat');
    final lng = prefs.getDouble('location_lng');
    final address = prefs.getString('location_address');
    final isManual = prefs.getBool('location_is_manual') ?? false;
    final recentLocations = _loadRecentLocations(prefs);

    if (lat != null && lng != null) {
      state = LocationState(
        latitude: lat,
        longitude: lng,
        address: address,
        isManual: isManual,
        recentLocations: recentLocations,
      );
    } else {
      state = state.copyWith(recentLocations: recentLocations);
    }
  }

  // SharedPreferences에서 최근 위치 목록 불러오기
  List<RecentLocation> _loadRecentLocations(SharedPreferences prefs) {
    final json = prefs.getString('recent_locations');
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => RecentLocation.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  // 최근 위치 목록에 추가 (중복 주소 제거, 최대 5개)
  Future<List<RecentLocation>> _addToRecent(
    SharedPreferences prefs,
    RecentLocation newLocation,
  ) async {
    final recent = _loadRecentLocations(prefs).toList();
    // 같은 주소 중복 제거
    recent.removeWhere((r) => r.address == newLocation.address);
    recent.insert(0, newLocation);
    if (recent.length > 5) recent.removeLast();
    await prefs.setString('recent_locations', jsonEncode(recent.map((r) => r.toMap()).toList()));
    return recent;
  }

  // GPS로 현재 위치 가져오기
  Future<void> fetchCurrentLocation() async {
    state = state.copyWith(isLoading: true);
    final result = await _service.getCurrentLocation();

    if (result.isSuccess) {
      final pos = result.position!;
      final address = result.address ?? state.address;
      final prefs = await SharedPreferences.getInstance();

      // 주소가 있으면 히스토리에 추가
      final recent = address != null
          ? await _addToRecent(prefs, RecentLocation(
              address: address,
              latitude: pos.latitude,
              longitude: pos.longitude,
            ))
          : state.recentLocations;

      await prefs.setDouble('location_lat', pos.latitude);
      await prefs.setDouble('location_lng', pos.longitude);
      if (address != null) await prefs.setString('location_address', address);
      await prefs.setBool('location_is_manual', false);

      state = LocationState(
        latitude: pos.latitude,
        longitude: pos.longitude,
        address: address,
        isManual: false,
        isLoading: false,
        recentLocations: recent,
      );
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
    final prefs = await SharedPreferences.getInstance();
    final recent = await _addToRecent(prefs, RecentLocation(
      address: address,
      latitude: latitude,
      longitude: longitude,
    ));

    await prefs.setDouble('location_lat', latitude);
    await prefs.setDouble('location_lng', longitude);
    await prefs.setString('location_address', address);
    await prefs.setBool('location_is_manual', true);

    state = LocationState(
      latitude: latitude,
      longitude: longitude,
      address: address,
      isManual: true,
      recentLocations: recent,
    );
  }

  // 주소 텍스트 → 좌표 변환 후 저장 (직접 입력용)
  Future<bool> setManualLocationByAddress(String inputAddress) async {
    try {
      final locations = await locationFromAddress(inputAddress);
      if (locations.isEmpty) return false;

      final loc = locations.first;
      final resolvedAddress = await _service.coordsToAddress(loc.latitude, loc.longitude);

      await setManualLocation(
        latitude: loc.latitude,
        longitude: loc.longitude,
        address: resolvedAddress ?? inputAddress,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // 최근 위치 선택 → 저장된 좌표 그대로 사용 (재변환 없음)
  Future<void> selectRecentLocation(RecentLocation recent) async {
    await setManualLocation(
      latitude: recent.latitude,
      longitude: recent.longitude,
      address: recent.address,
    );
  }

  Future<void> openSettings() => _service.openAppSettings();
  Future<LocationPermission> checkPermission() => _service.checkPermission();
}
