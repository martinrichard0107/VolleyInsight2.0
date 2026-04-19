import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:system_recorder/models/event.dart';
import 'package:system_recorder/models/player.dart';

class ApiService {
  // Android 模擬器: http://10.0.2.2:3000/api
  // iOS 模擬器 / mac 本機: http://127.0.0.1:3000/api
  // 實機: http://你的電腦區網IP:3000/api
  static const String baseUrl = 'http://127.0.0.1:3000/api';
  static const String defaultTeamId = 't1';

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final parsed = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return parsed;
    return parsed.replace(
      queryParameters: query.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  static Future<List<Player>> fetchPlayers({String teamId = defaultTeamId}) async {
    final response = await http.get(_uri('/players', {'team_id': teamId}));
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((e) => Player.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  static Future<Map<String, dynamic>> startMatch({
    required String teamId,
    required String opponentName,
  }) async {
    final response = await http.post(
      _uri('/matches/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'team_id': teamId,
        'opponent_name': opponentName,
      }),
    );
    _ensureSuccess(response, expectedCodes: {201});
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  static Future<void> saveLineups({
    required String matchId,
    required int setNumber,
    required List<Map<String, dynamic>> lineups,
  }) async {
    final response = await http.post(
      _uri('/lineups/batch'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'match_id': matchId,
        'set_number': setNumber,
        'lineups': lineups,
      }),
    );
    _ensureSuccess(response, expectedCodes: {201});
  }

  static Future<Map<String, dynamic>> createEvent(Map<String, dynamic> eventData) async {
    final response = await http.post(
      _uri('/events'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(eventData),
    );
    _ensureSuccess(response, expectedCodes: {201});
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  static Future<void> deleteEvent(String eventId) async {
    final response = await http.delete(_uri('/events/$eventId'));
    _ensureSuccess(response);
  }

  static Future<void> finishMatch({
    required String matchId,
    required int ourSetsWon,
    required int opponentSetsWon,
    required String result,
    required List<Map<String, dynamic>> sets,
  }) async {
    final response = await http.patch(
      _uri('/matches/$matchId/finish'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'our_sets_won': ourSetsWon,
        'opponent_sets_won': opponentSetsWon,
        'result': result,
        'sets': sets,
      }),
    );
    _ensureSuccess(response);
  }

  static Future<List<EventLog>> fetchEvents(String matchId) async {
    final response = await http.get(_uri('/matches/$matchId/events'));
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((e) => EventLog.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchDashboard(String matchId) async {
    final response = await http.get(_uri('/matches/$matchId/dashboard'));
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static void _ensureSuccess(http.Response response, {Set<int>? expectedCodes}) {
    final okCodes = expectedCodes ?? {200};
    if (!okCodes.contains(response.statusCode)) {
      throw Exception('API ${response.statusCode}: ${response.body}');
    }
  }
}
