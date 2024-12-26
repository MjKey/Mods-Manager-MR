import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) 
        ?? AppLocalizations(const Locale('en'));
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
      'drag_drop_instruction': 'Drag and drop mod files here or use the + button',
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
      'rename_mod': 'Rename mod',
      'mod_name': 'Mod name',
      'enter_new_name': 'Enter new name',
      'file_name': 'File name',
      'sort_by': 'Sort by',
      'sort_by_date': 'By date added',
      'sort_by_name': 'By name',
      'sort_by_size': 'By size',
      'search_mods': 'Search mods',
      'search_placeholder': 'Search by name or tags',
      'no_mods_found': 'No mods found',
      'play_with_steam': 'Play via Steam',
      'play_with_launcher': 'Play via Launcher',
      'steam_not_found': 'Steam is not installed',
      'disabled_mods_folder': 'Disabled mods folder',
      'disabled_mods_folder_desc': 'Choose where to store disabled mods (by default they are stored in a temporary folder)',
      'select_folder': 'Select folder',
      'change_folder': 'Change folder',
      'select_disabled_mods_folder': 'Select folder for disabled mods',
      'change_game_folder': 'Change game folder',
      'game_folder_desc': 'Current game folder path',
      'game_folder_changed': 'Game folder changed successfully',
      'add_mod': 'Add mod',
      'mod_exists': 'Mod already exists',
      'mod_exists_desc': 'A mod with this name already exists. Do you want to replace it?',
      'replace': 'Replace',
      'drop_files_here': 'Drop mod files here',
      'file_not_found': 'File not found',
      'invalid_file_format': 'Invalid file format. Only .pak files are supported',
      'error_copying_file': 'Error copying file',
      'made_with_love': 'Made with ❤️ by MjKey.ru',
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
      'drag_drop_instruction': 'Перетащите файлы модов сюда или используйте кнопку +',
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
      'rename_mod': 'Переименовать мод',
      'mod_name': 'Название мода',
      'enter_new_name': 'Введите новое название',
      'file_name': 'Имя файла',
      'sort_by': 'Сортировать',
      'sort_by_date': 'По дате добавления',
      'sort_by_name': 'По названию',
      'sort_by_size': 'По размеру',
      'search_mods': 'Поиск модов',
      'search_placeholder': 'Поиск по названию или тегам',
      'no_mods_found': 'Моды не найдены',
      'play_with_steam': 'Запустить через Steam',
      'play_with_launcher': 'Запустить через Лаунчер',
      'steam_not_found': 'Steam не установлен',
      'disabled_mods_folder': 'Папка для выключенных модов',
      'disabled_mods_folder_desc': 'Выберите, где хранить выключенные моды (по умолчанию они хранятся во временной папке)',
      'select_folder': 'Выбрать папку',
      'change_folder': 'Изменить папку',
      'select_disabled_mods_folder': 'Выберите папку для выключенных модов',
      'change_game_folder': 'Изменить папку игры',
      'game_folder_desc': 'Текущий путь к папке игры',
      'game_folder_changed': 'Папка игры успешно изменена',
      'add_mod': 'Добавить мод',
      'mod_exists': 'Мод уже существует',
      'mod_exists_desc': 'Мод с таким именем уже существует. Хотите заменить его?',
      'replace': 'Заменить',
      'drop_files_here': 'Перетащите файлы модов сюда',
      'file_not_found': 'Файл не найден',
      'invalid_file_format': 'Неверный формат файла. Поддерживаются только .pak файлы',
      'error_copying_file': 'Ошибка копирования файла',
      'made_with_love': 'Сделано с ❤️ от MjKey.ru',
    },
  };

  String get(String key) {
    final languageMap = _localizedValues[locale.languageCode];
    if (languageMap == null) {
      return _localizedValues['en']?[key] ?? key;
    }
    return languageMap[key] ?? _localizedValues['en']?[key] ?? key;
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