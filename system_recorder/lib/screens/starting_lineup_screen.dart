import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../providers/match_provider.dart';
import '../services/api_service.dart';
import 'match_score_screen.dart';

class StartingLineupScreen extends StatefulWidget {
  const StartingLineupScreen({super.key});

  @override
  State<StartingLineupScreen> createState() => _StartingLineupScreenState();
}

class _StartingLineupScreenState extends State<StartingLineupScreen> {
  final TextEditingController _opponentController = TextEditingController();

  Map<int, MapEntry<Player, PlayerRole>?> selectedStarters = {
    1: null,
    2: null,
    3: null,
    4: null,
    5: null,
    6: null,
  };
  Player? selectedLibero;

  List<Player> teamPlayers = [];
  bool isLoading = true;
  bool isStarting = false;

  @override
  void initState() {
    super.initState();
    _fetchPlayers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<MatchProvider>(context, listen: false);
      if (provider.positions[CourtPosition.p1] != null) {
        _opponentController.text = provider.opponentName;
        for (int i = 1; i <= 6; i++) {
          final player = provider.getPlayerAtPosition(_intToCourtPos(i));
          if (player != null) {
            selectedStarters[i] = MapEntry(player, player.role);
          }
        }
        selectedLibero = provider.currentLibero;
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _opponentController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlayers() async {
    try {
      final players = await ApiService.fetchPlayers();
      if (!mounted) return;
      setState(() {
        teamPlayers = players;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('無法讀取球員名單：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  CourtPosition _intToCourtPos(int i) {
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
        return CourtPosition.p1;
    }
  }

  String _getRoleName(PlayerRole role) {
    switch (role) {
      case PlayerRole.setter:
        return '舉球';
      case PlayerRole.outside:
        return '大砲';
      case PlayerRole.opposite:
        return '副攻';
      case PlayerRole.middle:
        return '攔中';
      case PlayerRole.libero:
        return '自由';
    }
  }

  void _selectPlayer(int? position) {
    final sorted = List<Player>.from(teamPlayers)
      ..sort((a, b) {
        final aUsed = selectedStarters.values.any((e) => e?.key.id == a.id) || selectedLibero?.id == a.id;
        final bUsed = selectedStarters.values.any((e) => e?.key.id == b.id) || selectedLibero?.id == b.id;
        if (aUsed && !bUsed) return 1;
        if (!aUsed && bUsed) return -1;
        return a.jerseyNo.compareTo(b.jerseyNo);
      });

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: ListView.builder(
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final player = sorted[index];
            final isUsed = selectedStarters.values.any((e) => e?.key.id == player.id) ||
                selectedLibero?.id == player.id;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isUsed ? Colors.grey[800] : Colors.orange,
                child: Text(
                  '${player.jerseyNo}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                player.name,
                style: TextStyle(color: isUsed ? Colors.white24 : Colors.white),
              ),
              subtitle: Text(
                _getRoleName(player.role),
                style: TextStyle(color: isUsed ? Colors.white24 : Colors.grey),
              ),
              enabled: !isUsed,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  if (position == null) {
                    selectedLibero = player;
                  } else {
                    selectedStarters[position] = MapEntry(player, player.role);
                  }
                });
              },
            );
          },
        ),
      ),
    );
  }

  void _showNodeOptions(int pos, Player player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Text(
            '設定 ${player.name} (P$pos)',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.manage_accounts, color: Colors.orange),
            title: Text(
              '更改他的場上角色 (目前: ${_getRoleName(selectedStarters[pos]!.value)})',
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _showRoleSelection(player, pos);
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz, color: Colors.blueAccent),
            title: const Text('換成其他球員', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _selectPlayer(pos);
            },
          ),
          ListTile(
            leading: const Icon(Icons.clear, color: Colors.redAccent),
            title: const Text('清空此位置', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              setState(() => selectedStarters[pos] = null);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _showRoleSelection(Player player, int position) {
    var currentRole = selectedStarters[position]!.value;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: Text('設定 ${player.name} 的角色', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: PlayerRole.values
                .where((role) => role != PlayerRole.libero)
                .map((role) => RadioListTile<PlayerRole>(
                      title: Text(
                        _getRoleName(role),
                        style: const TextStyle(color: Colors.white),
                      ),
                      value: role,
                      groupValue: currentRole,
                      activeColor: Colors.orange,
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => currentRole = value);
                        setState(() => selectedStarters[position] = MapEntry(player, value));
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _startMatch() async {
    setState(() => isStarting = true);
    final provider = Provider.of<MatchProvider>(context, listen: false);
    try {
      final hasExistingMatch = provider.matchId.isNotEmpty;
      if (hasExistingMatch) {
        await provider.startNextSet(
          allPlayers: teamPlayers,
          rotation: selectedStarters,
          libero: selectedLibero,
          opponentName: _opponentController.text.trim(),
        );
      } else {
        await provider.initializeMatch(
          allPlayers: teamPlayers,
          rotation: selectedStarters,
          libero: selectedLibero,
          opponentName: _opponentController.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MatchScoreScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('開始比賽失敗：$e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isStarting = false);
      }
    }
  }

  Widget _buildNode(int pos, {bool isLibero = false}) {
    final entry = isLibero ? null : selectedStarters[pos];
    final player = isLibero ? selectedLibero : entry?.key;
    return GestureDetector(
      onTap: () {
        if (player == null) {
          _selectPlayer(isLibero ? null : pos);
        } else if (isLibero) {
          _selectPlayer(null);
        } else {
          _showNodeOptions(pos, player);
        }
      },
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: player == null
                  ? Colors.transparent
                  : (isLibero ? Colors.redAccent : Colors.orange[800]),
              border: Border.all(
                color: player == null ? Colors.grey : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                player == null ? (isLibero ? 'L' : 'P$pos') : '${player.jerseyNo}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            player == null
                ? '選人'
                : '${player.name}\n${isLibero ? "自由" : _getRoleName(entry!.value)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    final ready = !selectedStarters.values.contains(null) && selectedLibero != null;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(title: const Text('賽前先發設定'), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: TextField(
                controller: _opponentController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: '對手名稱',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const Text('網子', style: TextStyle(color: Colors.white24, letterSpacing: 8)),
            const Divider(color: Colors.white24, indent: 80, endIndent: 80),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [_buildNode(4), _buildNode(3), _buildNode(2)],
            ),
            const SizedBox(height: 35),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [_buildNode(5), _buildNode(6), _buildNode(1)],
            ),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                children: [
                  _buildNode(0, isLibero: true),
                  const SizedBox(width: 20),
                  const Text('自由球員', style: TextStyle(color: Colors.white38)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        ready && !isStarting ? Colors.orange[800] : Colors.grey[850],
                  ),
                  onPressed: ready && !isStarting ? _startMatch : null,
                  child: isStarting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          ready ? '開始比賽' : '尚未選齊人員',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
