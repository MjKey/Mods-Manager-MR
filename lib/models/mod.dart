class Mod {
  final String name;
  String path;
  bool isEnabled;
  int? fileSize;

  Mod({
    required this.name,
    required this.path,
    this.isEnabled = false,
    this.fileSize,
  });

  String get formattedSize {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'isEnabled': isEnabled,
    'fileSize': fileSize,
  };

  factory Mod.fromJson(Map<String, dynamic> json) => Mod(
    name: json['name'],
    path: json['path'],
    isEnabled: json['isEnabled'],
    fileSize: json['fileSize'],
  );
} 