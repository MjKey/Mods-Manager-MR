import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/localization_service.dart';

class NexusModsService {
  static const String _baseUrl = 'https://api.nexusmods.com/v1';
  // hard coded api key =bad uwu :(
  static const String _apiKey = 'LdEvSqvTfKatcESMCj3jRuPGX43UuBac8V9qD3BJUPil/y03PQ==--cQ8QtdwiQk6hCjR3--KqPLEmtcF8ivhivqSzBHXw==';
  static final LocalizationService _localization = LocalizationService();

  static Future<Map<String, dynamic>> getModInfo(String url) async {
    final modId = _extractModId(url);
    if (modId == null) {
      throw Exception(_localization.translate('nexus_mods.errors.invalid_url'));
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/games/marvelrivals/mods/$modId.json'),
      headers: {
        'apikey': _apiKey,
        'accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(_localization.translate('nexus_mods.errors.get_info_failed', {'code': response.statusCode.toString()}));
    }
  }

  static int? _extractModId(String url) {
    final regex = RegExp(r'nexusmods\.com/marvelrivals/mods/(\d+)(\?.*|$)');
    final match = regex.firstMatch(url);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }
} 