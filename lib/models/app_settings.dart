class AppSettings {
  bool autoEnableMods;
  bool showFileSize;
  String language;
  String? disabledModsPath;

  AppSettings({
    this.autoEnableMods = false,
    this.showFileSize = true,
    this.language = 'en',
    this.disabledModsPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'autoEnableMods': autoEnableMods,
      'showFileSize': showFileSize,
      'language': language,
      'disabledModsPath': disabledModsPath,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      autoEnableMods: json['autoEnableMods'] ?? false,
      showFileSize: json['showFileSize'] ?? true,
      language: json['language'] ?? 'en',
      disabledModsPath: json['disabledModsPath'],
    );
  }

  AppSettings copyWith({
    bool? autoEnableMods,
    bool? showFileSize,
    String? language,
    String? disabledModsPath,
  }) {
    return AppSettings(
      autoEnableMods: autoEnableMods ?? this.autoEnableMods,
      showFileSize: showFileSize ?? this.showFileSize,
      language: language ?? this.language,
      disabledModsPath: disabledModsPath ?? this.disabledModsPath,
    );
  }
} 