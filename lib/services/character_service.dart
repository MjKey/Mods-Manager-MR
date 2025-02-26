import 'dart:io';
import 'package:path/path.dart' as path;

class CharacterService {
  static final Map<String, String> _characterIds = {
    '1011': 'Hulk',
    '1014': 'The Punisher',
    '1015': 'Storm',
    '1016': 'Loki',
    '1017': 'Human Torch',
    '1018': 'Dr. Strange',
    '1020': 'Mantis',
    '1021': 'Hawkeye',
    '1022': 'Captain America',
    '1023': 'Rocket Racoon',
    '1024': 'Hela',
    '1025': 'Dagger',
    '1026': 'Black Panther',
    '1027': 'Groot',
    '1028': 'Ultron',
    '1029': 'Magik',
    '1030': 'Moon Knight',
    '1031': 'Luna Snow',
    '1032': 'Squirrel Girl',
    '1033': 'Black Widow',
    '1034': 'Ironman',
    '1035': 'Venom',
    '1036': 'Spider-Man',
    '1037': 'Magneto',
    '1038': 'Scarlet Witch',
    '1039': 'Thor',
    '1040': 'Mr. Fantastic',
    '1041': 'Winter Soldier',
    '1042': 'Peni Parker',
    '1043': 'Star Lord',
    '1044': 'Blade',
    '1045': 'Namor',
    '1046': 'Adam Warlock',
    '1047': 'Jeff',
    '1048': 'Psylocke',
    '1049': 'Wolverine',
    '1050': 'Invisible Woman',
    '1051': 'The Thing',
    '1052': 'Iron Fist',
    '4011': 'Spider Zero',
    '4012': 'Master Weaver',
    '4017': 'Galacta',
  };

  static String? getCharacterName(String id) {
    return _characterIds[id];
  }

  static Future<String?> detectCharacterFromModPath(String modPath) async {
    final charactersDir = path.join(modPath, 'Marvel', 'Content', 'Marvel', 'Characters');
    final directory = Directory(charactersDir);
    if (!await directory.exists()) return null;

    // Получаем список директорий в папке Characters
    final entries = await directory.list().toList();
    for (var entry in entries) {
      if (entry is Directory) {
        final dirName = path.basename(entry.path);
        final characterName = getCharacterName(dirName);
        if (characterName != null) {
          return characterName;
        }
      }
    }
    return null;
  }
} 