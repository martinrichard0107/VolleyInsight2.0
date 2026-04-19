import 'package:system_recorder/models/player.dart';

enum EventCategory { serve, receive, set, attack, tip, block, error, oppError }

enum EventOutcome { teamPoint, oppPoint, neutral }

class EventLog {
  final String id;
  final String matchId;
  final String setNumber;
  final String rallyId;
  final DateTime timestamp;

  final String playerId;
  final String playerName;
  final int playerJerseyNo;
  final PlayerRole playerRole;
  final CourtPosition positionAtTime;

  final EventCategory category;
  final String detailType;

  final EventOutcome outcome;
  final int scoreTeamA;
  final int scoreTeamB;

  final bool isForcedError;
  final String pointReason;
  final bool rotationApplied;

  final dynamic beforeStateSnapshot;

  EventLog({
    required this.id,
    required this.matchId,
    required this.setNumber,
    required this.rallyId,
    required this.timestamp,
    required this.playerId,
    required this.playerName,
    required this.playerJerseyNo,
    required this.playerRole,
    required this.positionAtTime,
    required this.category,
    required this.detailType,
    required this.outcome,
    required this.scoreTeamA,
    required this.scoreTeamB,
    required this.isForcedError,
    required this.pointReason,
    required this.rotationApplied,
    this.beforeStateSnapshot,
  });

  factory EventLog.fromMap(Map<String, dynamic> map) {
    return EventLog(
      id: map['id']?.toString() ?? '',
      matchId: map['match_id']?.toString() ?? map['matchId']?.toString() ?? '',
      setNumber: (map['set_number'] ?? map['setNumber'] ?? '').toString(),
      rallyId: map['rally_id']?.toString() ?? map['rallyId']?.toString() ?? '',
      timestamp: DateTime.tryParse(
            map['created_at']?.toString() ??
                map['timestamp']?.toString() ??
                DateTime.now().toIso8601String(),
          ) ??
          DateTime.now(),
      playerId: map['player_id']?.toString() ?? map['playerId']?.toString() ?? '',
      playerName: map['player_name']?.toString() ?? map['playerName']?.toString() ?? '',
      playerJerseyNo: _parseInt(map['jersey_no'] ?? map['player_jersey_no'] ?? map['playerJerseyNo']),
      playerRole: parseRole(map['player_role_at_time'] ?? map['playerRole']),
      positionAtTime: parseCourtPosition(map['position_at_time'] ?? map['positionAtTime']),
      category: parseEventCategory(map['category']),
      detailType: (map['detail_type'] ?? map['detailType'] ?? '').toString(),
      outcome: parseEventOutcome(map['outcome']),
      scoreTeamA: _parseInt(map['score_team_a'] ?? map['scoreTeamA']),
      scoreTeamB: _parseInt(map['score_team_b'] ?? map['scoreTeamB']),
      isForcedError: _parseBool(map['is_forced_error'] ?? map['isForcedError']),
      pointReason: (map['point_reason'] ?? map['pointReason'] ?? '').toString(),
      rotationApplied: _parseBool(map['rotation_applied'] ?? map['rotationApplied']),
      beforeStateSnapshot: map['beforeStateSnapshot'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'match_id': matchId,
      'set_number': int.tryParse(setNumber) ?? 1,
      'rally_id': rallyId,
      'player_id': playerId,
      'player_name': playerName,
      'jersey_no': playerJerseyNo,
      'player_role_at_time': playerRole.name,
      'position_at_time': positionAtTime.name,
      'category': category.name,
      'detail_type': detailType,
      'outcome': outcome.name,
      'score_team_a': scoreTeamA,
      'score_team_b': scoreTeamB,
      'is_our_serve': 0,
      'is_forced_error': isForcedError ? 1 : 0,
      'point_reason': pointReason,
      'rotation_applied': rotationApplied ? 1 : 0,
      'created_at': timestamp.toIso8601String(),
    };
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    return value?.toString() == '1' || value?.toString().toLowerCase() == 'true';
  }
}

EventCategory parseEventCategory(dynamic raw) {
  final value = (raw ?? '').toString().toLowerCase().replaceAll('eventcategory.', '');
  return EventCategory.values.firstWhere(
    (e) => e.name.toLowerCase() == value,
    orElse: () => EventCategory.attack,
  );
}

EventOutcome parseEventOutcome(dynamic raw) {
  final value = (raw ?? '').toString().toLowerCase().replaceAll('eventoutcome.', '');
  return EventOutcome.values.firstWhere(
    (e) => e.name.toLowerCase() == value,
    orElse: () => EventOutcome.neutral,
  );
}
