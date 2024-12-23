class AppSettings {
  bool autoEnableMods;
  bool showFileSize;
  String? customModsFolder;
  String language;

  AppSettings({
    this.autoEnableMods = false,
    this.showFileSize = true,
    this.customModsFolder,
    this.language = 'en',
  });

  Map<String, dynamic> toJson() => {
    'autoEnableMods': autoEnableMods,
    'showFileSize': showFileSize,
    'customModsFolder': customModsFolder,
    'language': language,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    autoEnableMods: json['autoEnableMods'] ?? false,
    showFileSize: json['showFileSize'] ?? true,
    customModsFolder: json['customModsFolder'],
    language: json['language'] ?? 'en',
  );
} 