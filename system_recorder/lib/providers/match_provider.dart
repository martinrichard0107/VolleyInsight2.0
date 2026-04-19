import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../services/rotation_service.dart';
import '../services/libero_service.dart';
import '../services/event_rules.dart';
import '../services/api_service.dart';

class MatchProvider extends ChangeNotifier {
  MatchProvider();

  final Uuid _uuid = const Uuid();

  String _matchId = '';
  int _currentSet = 1;
  String _currentRallyId = const Uuid().v4();
  String _opponentName = '對手隊伍';
  String _teamId = ApiService.defaultTeamId;

  int _scoreTeamA = 0;
  int _scoreTeamB = 0;
  bool _isOurServe = true;

  final List<String> _setScoreHistory = [];
  List<Player> _allPlayers = [];
  final Map<String, Player> _playerMap = {};

  Map<CourtPosition, String?> _positions = {
    CourtPosition.p1: null,
    CourtPosition.p2: null,
    CourtPosition.p3: null,
    CourtPosition.p4: null,
    CourtPosition.p5: null,
    CourtPosition.p6: null,
  };

  String? _liberoId;
  bool _isLiberoOnCourt = false;
  String? _pairedPlayerId;
  String? _selectedPlayerId;

  final List<EventLog> _eventHistory = [];
  final List<PlayLog> _matchPlayLogs = [];

  int _currentTeamRotation = 1;
  bool _isBusy = false;

  String get matchId => _matchId;
  int get currentSet => _currentSet;
  String get currentRallyId => _currentRallyId;
  String get opponentName => _opponentName;
  String get teamId => _teamId;
  int get scoreTeamA => _scoreTeamA;
  int get scoreTeamB => _scoreTeamB;
  bool get isOurServe => _isOurServe;
  bool get isBusy => _isBusy;
  Map<CourtPosition, String?> get positions => _positions;
  String? get selectedPlayerId => _selectedPlayerId;
  List<String> get setScoreHistory => List.unmodifiable(_setScoreHistory);
  List<EventLog> get history => List.unmodifiable(_eventHistory.reversed);
  List<PlayLog> get matchPlayLogs => List.unmodifiable(_matchPlayLogs);
  int get currentTeamRotation => _currentTeamRotation;

  List<EventLog> get currentSetHistory => _eventHistory
      .where((e) => e.setNumber == _currentSet.toString())
      .toList()
      .reversed
      .toList();

  EventLog? get lastEvent => _eventHistory.isNotEmpty ? _eventHistory.last : null;

  Player? get selectedPlayer {
    final id = _selectedPlayerId;
    if (id == null) return null;
    return _playerMap[id];
  }

  Player? get currentLibero {
    final id = _liberoId;
    if (id == null) return null;
    return _playerMap[id];
  }

  List<Player> get benchPlayers {
    final onCourtIds = _positions.values.whereType<String>().toSet();
    if (_liberoId != null) {
      onCourtIds.add(_liberoId!);
    }
    return _allPlayers.where((p) => !onCourtIds.contains(p.id)).toList();
  }

  int get totalAttacks =>
      _eventHistory.where((e) => e.category == EventCategory.attack).length;

  int get totalReceives =>
      _eventHistory.where((e) => e.category == EventCategory.receive).length;

  double get attackEfficiency {
    final attacks =
        _eventHistory.where((e) => e.category == EventCategory.attack).toList();
    if (attacks.isEmpty) return 0.0;
    final kills = attacks.where((e) => e.detailType == 'Kill').length;
    final errors =
        attacks.where((e) => e.detailType == 'BlockedDown' || e.detailType == 'Out').length;
    return (kills - errors) / attacks.length;
  }

  double get passQuality {
    final receives =
        _eventHistory.where((e) => e.category == EventCategory.receive).toList();
    if (receives.isEmpty) return 0.0;

    double totalWeight = 0;
    for (final receive in receives) {
      if (receive.detailType == 'Perfect') {
        totalWeight += 3;
      } else if (receive.detailType == 'Good') {
        totalWeight += 2;
      } else if (receive.detailType == 'Bad') {
        totalWeight += 1;
      }
    }
    return totalWeight / receives.length;
  }

  List<Map<String, dynamic>> getBoxScore() {
    final activePlayerIds = _eventHistory.map((e) => e.playerId).toSet();
    return activePlayerIds.map((id) {
      final player = _playerMap[id];
      final playerEvents = _eventHistory.where((e) => e.playerId == id);
      return {
        'name': player?.name ?? 'Unknown',
        'jersey': player?.jerseyNo ?? 0,
        'pts': playerEvents.where((e) => e.outcome == EventOutcome.teamPoint).length,
        'kill': playerEvents
            .where((e) => e.category == EventCategory.attack && e.detailType == 'Kill')
            .length,
        'blk': playerEvents
            .where((e) => e.category == EventCategory.block && e.detailType == 'Kill')
            .length,
        'ace': playerEvents
            .where((e) => e.category == EventCategory.serve && e.detailType == 'Ace')
            .length,
        'err': playerEvents.where((e) => e.outcome == EventOutcome.oppPoint).length,
      };
    }).toList();
  }

  Future<void> initializeMatch({
    required List<Player> allPlayers,
    required Map<int, MapEntry<Player, PlayerRole>?> rotation,
    required Player? libero,
    required String opponentName,
  }) async {
    _setBusy(true);
    try {
      final match = await ApiService.startMatch(
        teamId: _teamId,
        opponentName: opponentName.isEmpty ? '對手隊伍' : opponentName,
      );

      _matchId = match['match']['id'].toString();
      _currentSet = 1;
      _setScoreHistory.clear();
      _eventHistory.clear();
      _matchPlayLogs.clear();
      _currentTeamRotation = 1;

      _allPlayers = allPlayers;
      _playerMap
        ..clear()
        ..addEntries(allPlayers.map((e) => MapEntry(e.id, e)));

      _opponentName = opponentName.isEmpty ? '對手隊伍' : opponentName;
      _scoreTeamA = 0;
      _scoreTeamB = 0;
      _selectedPlayerId = null;
      _isOurServe = true;
      _isLiberoOnCourt = false;
      _pairedPlayerId = null;
      _currentRallyId = _uuid.v4();

      _positions = {
        CourtPosition.p1: rotation[1]?.key.id,
        CourtPosition.p2: rotation[2]?.key.id,
        CourtPosition.p3: rotation[3]?.key.id,
        CourtPosition.p4: rotation[4]?.key.id,
        CourtPosition.p5: rotation[5]?.key.id,
        CourtPosition.p6: rotation[6]?.key.id,
      };
      _liberoId = libero?.id;

      await ApiService.saveLineups(
        matchId: _matchId,
        setNumber: _currentSet,
        lineups: _buildLineupPayload(libero),
      );
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> startNextSet({
    required List<Player> allPlayers,
    required Map<int, MapEntry<Player, PlayerRole>?> rotation,
    required Player? libero,
    required String opponentName,
  }) async {
    if (_scoreTeamA > 0 || _scoreTeamB > 0) {
      _setScoreHistory.add('$_scoreTeamA - $_scoreTeamB');
      _currentSet++;
    }

    _setBusy(true);
    try {
      _allPlayers = allPlayers;
      _playerMap
        ..clear()
        ..addEntries(allPlayers.map((e) => MapEntry(e.id, e)));
      _opponentName = opponentName.isEmpty ? '對手隊伍' : opponentName;
      _scoreTeamA = 0;
      _scoreTeamB = 0;
      _selectedPlayerId = null;
      _isOurServe = true;
      _isLiberoOnCourt = false;
      _pairedPlayerId = null;
      _currentRallyId = _uuid.v4();
      _currentTeamRotation = 1;

      _positions = {
        CourtPosition.p1: rotation[1]?.key.id,
        CourtPosition.p2: rotation[2]?.key.id,
        CourtPosition.p3: rotation[3]?.key.id,
        CourtPosition.p4: rotation[4]?.key.id,
        CourtPosition.p5: rotation[5]?.key.id,
        CourtPosition.p6: rotation[6]?.key.id,
      };
      _liberoId = libero?.id;

      await ApiService.saveLineups(
        matchId: _matchId,
        setNumber: _currentSet,
        lineups: _buildLineupPayload(libero),
      );
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> finishMatch() async {
    final sets = <Map<String, dynamic>>[];
    for (final entry in _setScoreHistory.asMap().entries) {
      final parts = entry.value.split('-');
      sets.add({
        'set_number': entry.key + 1,
        'our_score': int.tryParse(parts[0].trim()) ?? 0,
        'opponent_score': int.tryParse(parts[1].trim()) ?? 0,
      });
    }
    sets.add({
      'set_number': _currentSet,
      'our_score': _scoreTeamA,
      'opponent_score': _scoreTeamB,
    });

    await ApiService.finishMatch(
      matchId: _matchId,
      ourSetsWon: teamASetsWon,
      opponentSetsWon: teamBSetsWon,
      result: isMatchWon ? 'WIN' : 'LOSS',
      sets: sets,
    );
  }

  Player? getPlayerById(String id) => _playerMap[id];

  Player? getPlayerAtPosition(CourtPosition pos) {
    final playerId = _positions[pos];
    if (playerId == null) return null;
    return _playerMap[playerId];
  }

  void selectPlayer(String playerId) {
    _selectedPlayerId = playerId;
    notifyListeners();
  }

  void substitutePlayer(CourtPosition pos, String newPlayerId) {
    _positions[pos] = newPlayerId;
    _selectedPlayerId = newPlayerId;
    notifyListeners();
  }

  void manualAdjustScore(bool isTeamA, int delta) {
    if (isTeamA) {
      _scoreTeamA = (_scoreTeamA + delta).clamp(0, 99);
    } else {
      _scoreTeamB = (_scoreTeamB + delta).clamp(0, 99);
    }
    notifyListeners();
  }

  Future<void> handleEvent({
    required EventCategory category,
    required String detailType,
  }) async {
    if (_matchId.isEmpty) {
      throw Exception('比賽尚未初始化，請先從先發頁開始。');
    }

    final player = selectedPlayer ??
        const Player(
          id: 'system',
          jerseyNo: 0,
          name: 'Team',
          role: PlayerRole.setter,
        );

    final result = EventRules.calculateOutcome(
      category: category,
      detailType: detailType,
    );
    final snapshot = _createSnapshot();

    int nextScoreA = _scoreTeamA + result.scoreDeltaTeam;
    int nextScoreB = _scoreTeamB + result.scoreDeltaOpp;
    bool nextIsOurServe = _isOurServe;
    bool rotationHappened = false;
    Map<CourtPosition, String?> nextPositions =
        Map<CourtPosition, String?>.from(_positions);
    bool nextLiberoOnCourt = _isLiberoOnCourt;
    String? nextPairedPlayerId = _pairedPlayerId;
    int nextRotation = _currentTeamRotation;

    if (result.scoreDeltaTeam > 0) {
      if (!nextIsOurServe) {
        nextIsOurServe = true;
        final rotationResult = _previewRotation(
          positions: nextPositions,
          liberoId: _liberoId,
          isLiberoOnCourt: nextLiberoOnCourt,
          pairedPlayerId: nextPairedPlayerId,
          currentTeamRotation: nextRotation,
        );
        nextPositions = rotationResult.positions;
        nextLiberoOnCourt = rotationResult.isLiberoOnCourt;
        nextPairedPlayerId = rotationResult.pairedPlayerId;
        nextRotation = rotationResult.teamRotation;
        rotationHappened = true;
      }
    } else if (result.scoreDeltaOpp > 0) {
      nextIsOurServe = false;
    }

    final eventId = _uuid.v4();
    final eventTime = DateTime.now();
    final event = EventLog(
      id: eventId,
      matchId: _matchId,
      setNumber: _currentSet.toString(),
      rallyId: _currentRallyId,
      timestamp: eventTime,
      playerId: player.id,
      playerName: player.name,
      playerJerseyNo: player.jerseyNo,
      playerRole: player.role,
      positionAtTime: _getPlayerPos(player.id),
      category: category,
      detailType: detailType,
      outcome: result.outcome,
      scoreTeamA: nextScoreA,
      scoreTeamB: nextScoreB,
      isForcedError: result.isForcedError,
      pointReason: result.pointReason,
      rotationApplied: rotationHappened,
      beforeStateSnapshot: snapshot,
    );

    final playLog = PlayLog(
      eventId: eventId,
      setNumber: _currentSet,
      ourScore: nextScoreA,
      opponentScore: nextScoreB,
      isOurServe: nextIsOurServe,
      teamRotation: nextRotation,
      rallyId: _currentRallyId,
      playerId: player.id,
      playerName: player.name,
      jerseyNo: player.jerseyNo,
      playerPosition: _courtPositionToNumber(event.positionAtTime),
      actionType: category.name,
      actionResult: detailType,
    );

    _setBusy(true);
    try {
      await ApiService.createEvent({
        'id': event.id,
        'match_id': event.matchId,
        'set_number': _currentSet,
        'rally_id': event.rallyId,
        'player_id': event.playerId,
        'player_name': event.playerName,
        'jersey_no': event.playerJerseyNo,
        'player_role_at_time': event.playerRole.name,
        'position_at_time': event.positionAtTime.name,
        'category': event.category.name,
        'detail_type': event.detailType,
        'outcome': event.outcome.name,
        'score_team_a': event.scoreTeamA,
        'score_team_b': event.scoreTeamB,
        'is_our_serve': nextIsOurServe ? 1 : 0,
        'is_forced_error': event.isForcedError ? 1 : 0,
        'point_reason': event.pointReason,
        'rotation_applied': event.rotationApplied ? 1 : 0,
      });

      _scoreTeamA = nextScoreA;
      _scoreTeamB = nextScoreB;
      _isOurServe = nextIsOurServe;
      _positions = nextPositions;
      _isLiberoOnCourt = nextLiberoOnCourt;
      _pairedPlayerId = nextPairedPlayerId;
      _currentTeamRotation = nextRotation;

      _eventHistory.add(event);
      _matchPlayLogs.add(playLog);

      if (result.outcome != EventOutcome.neutral) {
        _currentRallyId = _uuid.v4();
      }
      _selectedPlayerId = null;
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> undo() async {
    if (_eventHistory.isEmpty) return;

    final lastLog = _eventHistory.last;
    final snapshot = lastLog.beforeStateSnapshot as Map<String, dynamic>;

    _setBusy(true);
    try {
      await ApiService.deleteEvent(lastLog.id);

      _eventHistory.removeLast();
      if (_matchPlayLogs.isNotEmpty) {
        _matchPlayLogs.removeLast();
      }

      _scoreTeamA = snapshot['scoreA'] as int;
      _scoreTeamB = snapshot['scoreB'] as int;
      _isOurServe = snapshot['isOurServe'] as bool;
      _isLiberoOnCourt = snapshot['isLiberoOnCourt'] as bool;
      _pairedPlayerId = snapshot['pairedPlayerId'] as String?;
      _currentRallyId = snapshot['rallyId'] as String;
      _positions = Map<CourtPosition, String?>.from(snapshot['positions'] as Map);
      _currentTeamRotation = snapshot['teamRotation'] as int? ?? 1;
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  void manualRotate({bool reverse = false}) {
    _positions = RotationService.rotatePositions(_positions, reverse: reverse);
    _currentTeamRotation = reverse
        ? (_currentTeamRotation == 1 ? 6 : _currentTeamRotation - 1)
        : (_currentTeamRotation == 6 ? 1 : _currentTeamRotation + 1);
    notifyListeners();
  }

  void manualLiberoToggle(CourtPosition pos) {
    if (_liberoId == null) return;
    final currentPlayerId = _positions[pos];
    if (currentPlayerId == _liberoId) {
      _swapLiberoOut(pos);
    } else {
      _pairedPlayerId = currentPlayerId;
      _positions[pos] = _liberoId;
      _isLiberoOnCourt = true;
    }
    notifyListeners();
  }

  int get teamASetsWon {
    int wins = 0;
    for (final score in _setScoreHistory) {
      final parts = score.split('-');
      if (parts.length == 2) {
        final a = int.tryParse(parts[0].trim()) ?? 0;
        final b = int.tryParse(parts[1].trim()) ?? 0;
        if (a > b) wins++;
      }
    }
    if (_scoreTeamA > _scoreTeamB) wins++;
    return wins;
  }

  int get teamBSetsWon {
    int wins = 0;
    for (final score in _setScoreHistory) {
      final parts = score.split('-');
      if (parts.length == 2) {
        final a = int.tryParse(parts[0].trim()) ?? 0;
        final b = int.tryParse(parts[1].trim()) ?? 0;
        if (b > a) wins++;
      }
    }
    if (_scoreTeamB > _scoreTeamA) wins++;
    return wins;
  }

  bool get isMatchWon => teamASetsWon >= teamBSetsWon;

  List<Map<String, dynamic>> _buildLineupPayload(Player? libero) {
    final payload = <Map<String, dynamic>>[];
    for (var index = 1; index <= 6; index++) {
      final pos = _numberToCourtPosition(index);
      final playerId = _positions[pos];
      if (playerId != null) {
        payload.add({
          'position': index,
          'player_id': playerId,
          'is_libero': 0,
        });
      }
    }
    if (libero != null) {
      payload.add({
        'position': 0,
        'player_id': libero.id,
        'is_libero': 1,
      });
    }
    return payload;
  }

  RotationPreview _previewRotation({
    required Map<CourtPosition, String?> positions,
    required String? liberoId,
    required bool isLiberoOnCourt,
    required String? pairedPlayerId,
    required int currentTeamRotation,
  }) {
    var nextPositions = Map<CourtPosition, String?>.from(positions);
    var nextIsLiberoOnCourt = isLiberoOnCourt;
    var nextPairedPlayerId = pairedPlayerId;

    if (nextIsLiberoOnCourt && liberoId != null) {
      CourtPosition? liberoPos;
      nextPositions.forEach((key, value) {
        if (value == liberoId) liberoPos = key;
      });
      if (liberoPos != null && LiberoService.shouldSwapOutBeforeRotation(liberoPos!)) {
        if (nextPairedPlayerId != null) {
          nextPositions[liberoPos!] = nextPairedPlayerId;
          nextIsLiberoOnCourt = false;
          nextPairedPlayerId = null;
        }
      }
    }

    nextPositions = RotationService.rotatePositions(nextPositions);
    final nextRotation = currentTeamRotation == 6 ? 1 : currentTeamRotation + 1;

    return RotationPreview(
      positions: nextPositions,
      isLiberoOnCourt: nextIsLiberoOnCourt,
      pairedPlayerId: nextPairedPlayerId,
      teamRotation: nextRotation,
    );
  }

  void _swapLiberoOut(CourtPosition pos) {
    if (_pairedPlayerId != null) {
      _positions[pos] = _pairedPlayerId;
      _isLiberoOnCourt = false;
      _pairedPlayerId = null;
    }
  }

  CourtPosition _getPlayerPos(String id) {
    return _positions.entries
        .firstWhere(
          (entry) => entry.value == id,
          orElse: () => const MapEntry(CourtPosition.bench, null),
        )
        .key;
  }

  Map<String, dynamic> _createSnapshot() {
    return {
      'scoreA': _scoreTeamA,
      'scoreB': _scoreTeamB,
      'isOurServe': _isOurServe,
      'positions': Map<CourtPosition, String?>.from(_positions),
      'isLiberoOnCourt': _isLiberoOnCourt,
      'pairedPlayerId': _pairedPlayerId,
      'rallyId': _currentRallyId,
      'teamRotation': _currentTeamRotation,
    };
  }

  CourtPosition _numberToCourtPosition(int i) {
    switch (i) {
      case 1:
        return CourtPosition.p1;
      case 2:
        return CourtPosition.p2;
      case 3:
        return CourtPosition.p3;
      case 4:
        return CourtPosition.p4;
      case 5:
        return CourtPosition.p5;
      case 6:
        return CourtPosition.p6;
      default:
        return CourtPosition.bench;
    }
  }

  int _courtPositionToNumber(CourtPosition position) {
    switch (position) {
      case CourtPosition.p1:
        return 1;
      case CourtPosition.p2:
        return 2;
      case CourtPosition.p3:
        return 3;
      case CourtPosition.p4:
        return 4;
      case CourtPosition.p5:
        return 5;
      case CourtPosition.p6:
        return 6;
      case CourtPosition.bench:
        return 0;
    }
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }
}

class RotationPreview {
  final Map<CourtPosition, String?> positions;
  final bool isLiberoOnCourt;
  final String? pairedPlayerId;
  final int teamRotation;

  RotationPreview({
    required this.positions,
    required this.isLiberoOnCourt,
    required this.pairedPlayerId,
    required this.teamRotation,
  });
}

class PlayLog {
  final String eventId;
  final int setNumber;
  final int ourScore;
  final int opponentScore;
  final bool isOurServe;
  final int teamRotation;
  final String rallyId;
  final String playerId;
  final String playerName;
  final int jerseyNo;
  final int playerPosition;
  final String actionType;
  final String actionResult;

  PlayLog({
    required this.eventId,
    required this.setNumber,
    required this.ourScore,
    required this.opponentScore,
    required this.isOurServe,
    required this.teamRotation,
    required this.rallyId,
    required this.playerId,
    required this.playerName,
    required this.jerseyNo,
    required this.playerPosition,
    required this.actionType,
    required this.actionResult,
  });

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'set_number': setNumber,
      'our_score': ourScore,
      'opponent_score': opponentScore,
      'is_our_serve': isOurServe ? 1 : 0,
      'team_rotation': teamRotation,
      'rally_id': rallyId,
      'player_id': playerId,
      'player_name': playerName,
      'jersey_no': jerseyNo,
      'player_position': playerPosition,
      'action_type': actionType,
      'action_result': actionResult,
    };
  }
}
