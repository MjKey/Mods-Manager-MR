import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Marvel Rivals Mod Manager',
      'select_game_folder': 'Select Game Folder',
      'welcome': 'Welcome to Marvel Rivals Mod Manager',
      'start_instruction': 'Select game folder to start',
      'invalid_folder': 'Invalid folder. Please select Marvel Rivals installation folder',
      'settings': 'Settings',
      'auto_enable_mods': 'Auto-enable mods',
      'auto_enable_mods_desc': 'Enable mods right after adding',
      'show_file_size': 'Show file size',
      'show_file_size_desc': 'Display mod file size in list',
      'mods_folder': 'Mods folder',
      'default_folder': 'Use default folder',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'delete_mod': 'Delete mod',
      'delete_mod_confirm': 'Are you sure you want to delete mod',
      'drag_drop_instruction': 'Drag .pak files here or click "Add mod" button',
      'adding_mod': 'Adding mod',
      'copying_file': 'Copying file',
      'language': 'Language',
      'error_copying': 'Error copying file',
      'error_deleting': 'Error deleting mod',
      'error_toggling': 'Error toggling mod',
      'close_app': 'Close application?',
      'unsaved_changes': 'You have unsaved changes. Are you sure you want to close the application?',
      'close': 'Close',
      'game_folder': 'Game folder',
      'export_mods': 'Export mods',
      'import_mods': 'Import mods',
      'export': 'Export',
      'import': 'Import',
      'mods_exported_to': 'Mods exported to',
      'export_error': 'Export error',
      'import_error': 'Import error',
      'imported_mods_count': 'Imported mods count',
      'add_tags': 'Add tags',
      'tag_color': 'Color',
      'tag_model': 'Model',
      'tag_sound': 'Sound',
      'tag_music': 'Music',
      'tag_other': 'Other',
      'select_tags': 'Select tags',
      'play_with_mods': 'Play with mods',
      'play_without_mods': 'Play without mods',
      'launcher_not_found': 'Game launcher not found',
      'play_game': 'Launch game',
      'play': 'Play',
    },
    'ru': {
      'app_title': 'Marvel Rivals Mod Manager',
      'select_game_folder': 'Выбрать папку с игрой',
      'welcome': 'Добро пожаловать в Marvel Rivals Mod Manager',
      'start_instruction': 'Для начала работы выберите папку с игрой',
      'invalid_folder': 'Выбрана неверная папка. Пожалуйста, выберите папку, где установлена Marvel Rivals',
      'settings': 'Настройки',
      'auto_enable_mods': 'Автоматически включать моды',
      'auto_enable_mods_desc': 'Включать моды сразу после добавления',
      'show_file_size': 'Показывать размер файлов',
      'show_file_size_desc': 'Отображать размер мода в списке',
      'mods_folder': 'Папка модов',
      'default_folder': 'Использовать папку по умолчанию',
      'save': 'Сохранить',
      'cancel': 'Отмена',
      'delete': 'Удалить',
      'delete_mod': 'Удалить мод',
      'delete_mod_confirm': 'Вы уверены, что хотите удалить мод',
      'drag_drop_instruction': 'Перетащите .pak файлы сюда или нажмите кнопку "Добавить мод"',
      'adding_mod': 'Добавление мода',
      'copying_file': 'Копирование файла',
      'language': 'Язык',
      'error_copying': 'Ошибка копирования файла',
      'error_deleting': 'Ошибка удаления мода',
      'error_toggling': 'Ошибка при переключении мода',
      'close_app': 'Закрыть приложение?',
      'unsaved_changes': 'У вас есть несохраненные изменения. Вы уверены, что хотите закрыть приложение?',
      'close': 'Закрыть',
      'game_folder': 'Папка игры',
      'export_mods': 'Экспорт модов',
      'import_mods': 'Импорт модов',
      'export': 'Экспорт',
      'import': 'Импорт',
      'mods_exported_to': 'Моды экспортированы в',
      'export_error': 'Ошибка экспорта',
      'import_error': 'Ошибка импорта',
      'imported_mods_count': 'Импортировано модов',
      'add_tags': 'Добавить теги',
      'tag_color': 'Цвет',
      'tag_model': 'Модель',
      'tag_sound': 'Звук',
      'tag_music': 'Музыка',
      'tag_other': 'Другое',
      'select_tags': 'Выберите теги',
      'play_with_mods': 'Играть с модами',
      'play_without_mods': 'Играть без модов',
      'launcher_not_found': 'Лаунчер игры не найден',
      'play_game': 'Запустить игру',
      'play': 'Играть',
    },
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']![key]!;
  }

  static List<Locale> supportedLocales = [
    const Locale('en'),
    const Locale('ru'),
  ];
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ru'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
} 