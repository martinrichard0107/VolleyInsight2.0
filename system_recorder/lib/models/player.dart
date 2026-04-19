enum CourtPosition {
  p1,
  p2,
  p3,
  p4,
  p5,
  p6,
  bench,
}

enum PlayerRole {
  setter,
  outside,
  opposite,
  middle,
  libero,
}

class Player {
  final String id;
  final int jerseyNo;
  final String name;
  final PlayerRole role;
  final String? pairedPlayerId;

  const Player({
    required this.id,
    required this.jerseyNo,
    required this.name,
    required this.role,
    this.pairedPlayerId,
  });

  Player copyWith({
    String? id,
    int? jerseyNo,
    String? name,
    PlayerRole? role,
    String? pairedPlayerId,
  }) {
    return Player(
      id: id ?? this.id,
      jerseyNo: jerseyNo ?? this.jerseyNo,
      name: name ?? this.name,
      role: role ?? this.role,
      pairedPlayerId: pairedPlayerId ?? this.pairedPlayerId,
    );
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id']?.toString() ?? '',
      jerseyNo: _parseInt(map['jersey_no'] ?? map['jerseyNo']),
      name: (map['name'] ?? 'Unknown').toString(),
      role: parseRole(map['primary_role'] ?? map['role']),
      pairedPlayerId: map['paired_player_id']?.toString() ?? map['pairedPlayerId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jersey_no': jerseyNo,
      'name': name,
      'primary_role': role.name,
      'paired_player_id': pairedPlayerId,
    };
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

PlayerRole parseRole(dynamic roleStr) {
  final raw = (roleStr ?? '').toString().toLowerCase();
  return PlayerRole.values.firstWhere(
    (e) => e.name.toLowerCase() == raw,
    orElse: () => PlayerRole.outside,
  );
}

String courtPositionName(CourtPosition position) => position.name.toUpperCase();

CourtPosition parseCourtPosition(dynamic raw) {
  final value = (raw ?? '').toString().toLowerCase().replaceAll('courtposition.', '');
  return CourtPosition.values.firstWhere(
    (e) => e.name.toLowerCase() == value,
    orElse: () => CourtPosition.bench,
  );
}
