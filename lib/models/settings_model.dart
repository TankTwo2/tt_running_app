class SettingsModel {
  final double pm25Threshold;
  final double tempMin;
  final double tempMax;
  final double rainThreshold;

  const SettingsModel({
    this.pm25Threshold = 35,
    this.tempMin = 5,
    this.tempMax = 28,
    this.rainThreshold = 30,
  });

  SettingsModel copyWith({
    double? pm25Threshold,
    double? tempMin,
    double? tempMax,
    double? rainThreshold,
  }) {
    return SettingsModel(
      pm25Threshold: pm25Threshold ?? this.pm25Threshold,
      tempMin: tempMin ?? this.tempMin,
      tempMax: tempMax ?? this.tempMax,
      rainThreshold: rainThreshold ?? this.rainThreshold,
    );
  }

  Map<String, double> toMap() => {
        'pm25Threshold': pm25Threshold,
        'tempMin': tempMin,
        'tempMax': tempMax,
        'rainThreshold': rainThreshold,
      };

  factory SettingsModel.fromMap(Map<String, double> map) => SettingsModel(
        pm25Threshold: map['pm25Threshold'] ?? 35,
        tempMin: map['tempMin'] ?? 5,
        tempMax: map['tempMax'] ?? 28,
        rainThreshold: map['rainThreshold'] ?? 30,
      );
}
