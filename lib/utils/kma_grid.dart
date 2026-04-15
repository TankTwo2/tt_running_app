import 'dart:math';

// 기상청 동네예보 격자 변환 유틸
// 위도/경도 → 기상청 nx, ny 격자 좌표로 변환
// 출처: 기상청 공식 변환 공식 (Lambert Conformal Conic Projection)

class KmaGrid {
  static const double _re = 6371.00877; // 지구 반경 (km)
  static const double _grid = 5.0;      // 격자 간격 (km)
  static const double _slat1 = 30.0;   // 표준 위도 1
  static const double _slat2 = 60.0;   // 표준 위도 2
  static const double _olon = 126.0;   // 기준점 경도
  static const double _olat = 38.0;    // 기준점 위도
  static const double _xo = 43.0;      // 기준점 X 격자
  static const double _yo = 136.0;     // 기준점 Y 격자

  // 위도/경도 → 기상청 격자(nx, ny) 변환
  static ({int nx, int ny}) toGrid(double lat, double lon) {
    const degrad = pi / 180.0;

    final re = _re / _grid;
    final slat1 = _slat1 * degrad;
    final slat2 = _slat2 * degrad;
    final olon = _olon * degrad;
    final olat = _olat * degrad;

    double sn = tan(pi * 0.25 + slat2 * 0.5) / tan(pi * 0.25 + slat1 * 0.5);
    sn = log(cos(slat1) / cos(slat2)) / log(sn);
    double sf = tan(pi * 0.25 + slat1 * 0.5);
    sf = pow(sf, sn) * cos(slat1) / sn;
    double ro = tan(pi * 0.25 + olat * 0.5);
    ro = re * sf / pow(ro, sn);

    double ra = tan(pi * 0.25 + lat * degrad * 0.5);
    ra = re * sf / pow(ra, sn);
    double theta = lon * degrad - olon;
    if (theta > pi) theta -= 2.0 * pi;
    if (theta < -pi) theta += 2.0 * pi;
    theta *= sn;

    final x = (ra * sin(theta) + _xo + 0.5).floor();
    final y = (ro - ra * cos(theta) + _yo + 0.5).floor();

    return (nx: x, ny: y);
  }
}
