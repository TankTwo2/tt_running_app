import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// 위치 관련 결과를 담는 클래스
// 성공이면 position + address에 값이 있고, 실패면 error에 메시지가 있음
class LocationResult {
  final Position? position;
  final String? address; // 변환된 주소 (예: 서울시 은평구 대조동)
  final String? error;

  const LocationResult({this.position, this.address, this.error});

  bool get isSuccess => position != null;
}

class LocationService {
  // 현재 위치 가져오기 (권한 요청 포함)
  Future<LocationResult> getCurrentLocation() async {
    // 1. 위치 서비스(GPS)가 켜져 있는지 확인
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(error: '위치 서비스가 꺼져 있습니다. 설정에서 켜주세요.');
    }

    // 2. 권한 상태 확인
    LocationPermission permission = await Geolocator.checkPermission();

    // 3. 권한이 없으면 요청
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationResult(error: '위치 권한이 거부되었습니다.');
      }
    }

    // 4. 영구적으로 거부된 경우 → 설정 앱으로 안내
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(error: '위치 권한이 영구적으로 거부되었습니다. 설정에서 직접 허용해주세요.');
    }

    // 5. 권한 OK → 현재 위치 반환
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // 배터리 절약을 위해 medium 사용
        ),
      );

      // 6. 위도/경도 → 주소 변환 (예: 서울시 송파구 방이동), 실패 시 한 번 재시도
      String? address = await coordsToAddress(position.latitude, position.longitude);
      if (address == null) {
        await Future.delayed(const Duration(seconds: 1));
        address = await coordsToAddress(position.latitude, position.longitude);
      }

      return LocationResult(position: position, address: address);
    } catch (e) {
      return LocationResult(error: '위치를 가져오지 못했습니다: $e');
    }
  }

  // 위도/경도 → 한국어 주소 변환 (예: 서울시 은평구 대조동)
  // 변환 실패 시 null 반환
  Future<String?> coordsToAddress(double lat, double lng) async {
    try {
      // placemarkFromCoordinates: 좌표를 주소 정보로 변환
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;

      final p = placemarks.first;
      // 한국 주소는 지역마다 필드 매핑이 달라서 케이스별 처리
      // 서울: administrativeArea=서울특별시, subLocality=구, thoroughfare=동
      // 경기도: administrativeArea=경기도, locality=시, subLocality=구, thoroughfare=없음(도로명은 street에 포함)

      // thoroughfare가 없을 때 street에서 도로명 추출
      // street 예시: "대한민국 경기도 고양시 덕양구 동세로 125"
      // subThoroughfare(번지)와 앞의 행정구역 제거 → "동세로"만 추출
      String? roadName;
      if ((p.thoroughfare?.isEmpty ?? true) && (p.street?.isNotEmpty ?? false)) {
        var street = p.street!;
        // 번지(subThoroughfare) 제거
        if (p.subThoroughfare?.isNotEmpty ?? false) {
          street = street.replaceAll(p.subThoroughfare!, '').trim();
        }
        // 앞의 "대한민국 " 제거
        street = street.replaceAll('대한민국 ', '');
        // 시/도, 시/군, 구 부분 제거 후 도로명만 남김
        for (final part in [
          p.administrativeArea,
          p.locality,
          p.subLocality,
        ]) {
          if (part?.isNotEmpty ?? false) {
            street = street.replaceAll(part!, '').trim();
          }
        }
        roadName = street.isEmpty ? null : street;
      }

      final parts = [
        p.administrativeArea,                                       // 시/도 (공통)
        if ((p.locality?.isNotEmpty ?? false)) p.locality,          // 시/군 (경기도 등)
        p.subLocality,                                              // 구
        (p.thoroughfare?.isNotEmpty ?? false) ? p.thoroughfare      // 동 (서울 등)
            : roadName,                                             // 도로명 (경기도 등)
      ].where((s) => s != null && s.isNotEmpty).toList();

      return parts.isNotEmpty ? parts.join(' ') : null;
    } catch (_) {
      // 변환 실패 시 null 반환 → 호출부에서 재시도
      return null;
    }
  }

  // 위치 권한 상태만 확인 (요청 없이)
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  // 앱 설정 화면 열기 (영구 거부 시 사용)
  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }
}
