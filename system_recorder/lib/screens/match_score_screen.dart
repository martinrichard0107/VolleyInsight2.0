import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../providers/match_provider.dart';
import 'starting_lineup_screen.dart';
import 'match_summary_screen.dart';

class MatchScoreScreen extends StatefulWidget {
  const MatchScoreScreen({super.key});

  @override
  State<MatchScoreScreen> createState() => _MatchScoreScreenState();
}

class _MatchScoreScreenState extends State<MatchScoreScreen> {
  int _selectedTabIndex = 2;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final Color _colBgDeep = const Color(0xFF131722);
  final Color _colBgPanel = const Color(0xFF1E2330);
  final Color _colCourt = const Color(0xFFE0AA68);
  final Color _colSelected = const Color(0xFFFACC15);
  final Color _btnSuccess = const Color(0xFF3B82F6);
  final Color _btnNeutral = const Color(0xFF4B5563);
  final Color _btnError = const Color(0xFFEF4444);

  final Map<CourtPosition, Alignment> _courtAlignments = {
    CourtPosition.p4: const Alignment(-0.75, -0.6),
    CourtPosition.p3: const Alignment(0.0, -0.6),
    CourtPosition.p2: const Alignment(0.75, -0.6),
    CourtPosition.p5: const Alignment(-0.75, 0.6),
    CourtPosition.p6: const Alignment(0.0, 0.6),
    CourtPosition.p1: const Alignment(0.75, 0.6),
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MatchProvider>();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _colBgDeep,
      endDrawer: _buildHistoryDrawer(provider),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(provider),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(flex: 4, child: _buildLeftColumn(provider)),
                      Expanded(flex: 6, child: _buildControlPanel(provider)),
                    ],
                  ),
                ),
                _buildBottomBar(provider),
              ],
            ),
          ),
          if (provider.isBusy)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(MatchProvider provider) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: _colBgDeep,
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showMatchControlMenu(context),
            icon: const Icon(Icons.menu, color: Colors.white),
          ),
          Expanded(
            child: Text(
              '第 ${provider.currentSet} 局  ·  ${provider.opponentName}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          _buildScoreBoard(provider),
        ],
      ),
    );
  }

  Widget _buildScoreBoard(MatchProvider provider) {
    return Row(
      children: [
        _scoreCard('我方', provider.scoreTeamA, Colors.orange),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(':', style: TextStyle(color: Colors.white70, fontSize: 24)),
        ),
        _scoreCard('對方', provider.scoreTeamB, Colors.blueAccent),
      ],
    );
  }

  Widget _scoreCard(String label, int score, Color color) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _colBgPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            '$score',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(MatchProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _colBgPanel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _colCourt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  ..._courtAlignments.entries.map(
                    (entry) => Align(
                      alignment: entry.value,
                      child: _buildPlayerNode(provider, entry.key),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: provider.isBusy ? null : () => _showSubstitutionMenu(context, provider),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('換人'),
                  style: ElevatedButton.styleFrom(backgroundColor: _colBgPanel),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: provider.isBusy ? null : () => provider.manualRotate(reverse: false),
                icon: const Icon(Icons.rotate_right, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: _colBgPanel),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: provider.isBusy ? null : () => provider.manualRotate(reverse: true),
                icon: const Icon(Icons.rotate_left, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: _colBgPanel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              final selectedPos = _getSelectedPosition(provider);
              final isBackRow = selectedPos == CourtPosition.p1 ||
                  selectedPos == CourtPosition.p6 ||
                  selectedPos == CourtPosition.p5;
              if (selectedPos != null && isBackRow) {
                provider.manualLiberoToggle(selectedPos);
              }
            },
            icon: const Icon(Icons.sports_volleyball),
            label: const Text('自由球員切換'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              backgroundColor: _colBgPanel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerNode(MatchProvider provider, CourtPosition pos) {
    final player = provider.getPlayerAtPosition(pos);
    final isSelected = provider.selectedPlayerId != null &&
        provider.positions[pos] == provider.selectedPlayerId;

    return GestureDetector(
      onTap: () {
        final playerId = provider.positions[pos];
        if (playerId != null) {
          provider.selectPlayer(playerId);
          _handleSmartTabSwitch(provider, pos);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: isSelected ? _colSelected : _colBgPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: player == null
            ? const Center(child: Icon(Icons.add, color: Colors.grey, size: 36))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${player.jerseyNo}',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      player.name,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.black87 : Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildControlPanel(MatchProvider provider) {
    final requirePlayer = _selectedTabIndex != 5;
    final hasPlayer = provider.selectedPlayer != null;
    final isLocked = _isTabLocked(provider, _selectedTabIndex);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      decoration: BoxDecoration(color: _colBgPanel, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              _buildTabItem(provider, '發球', 0),
              _buildTabItem(provider, '接球', 1),
              _buildTabItem(provider, '攻擊', 2),
              _buildTabItem(provider, '吊球', 3),
              _buildTabItem(provider, '攔網', 4),
              _buildTabItem(provider, '其他', 5),
            ],
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: (requirePlayer && !hasPlayer)
                ? _buildEmptyMessage("請先點擊球場上的球員")
                : (isLocked
                    ? _buildEmptyMessage("🔒 此球員無法執行此動作")
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildActionGrid(provider),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessage(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(msg.contains("🔒") ? Icons.lock : Icons.touch_app, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            msg,
            style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(MatchProvider provider, String title, int index) {
    final isActive = _selectedTabIndex == index;
    final isLocked = _isTabLocked(provider, index);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isLocked) {
            setState(() => _selectedTabIndex = index);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: isActive ? Colors.blue : Colors.transparent, width: 3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isLocked ? Colors.white12 : (isActive ? Colors.white : Colors.white38),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (isLocked)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.lock, size: 14, color: Colors.white12),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionGrid(MatchProvider provider) {
    List<Widget> buttons = [];
    switch (_selectedTabIndex) {
      case 0:
        buttons = [
          _buildBigButton(provider, 'Ace 得分', EventCategory.serve, 'Ace', _btnSuccess),
          _buildBigButton(provider, '發球成功 In', EventCategory.serve, 'InPlay', _btnNeutral),
          _buildBigButton(provider, '發球失誤', EventCategory.serve, 'Error', _btnError),
        ];
        break;
      case 1:
        buttons = [
          _buildBigButton(provider, '到位 Perfect', EventCategory.receive, 'Perfect', _btnNeutral),
          _buildBigButton(provider, '可打 Playable', EventCategory.receive, 'Good', _btnNeutral),
          _buildBigButton(provider, '不到位 Bad', EventCategory.receive, 'Bad', _btnNeutral),
          _buildBigButton(provider, '接球失誤', EventCategory.receive, 'Error', _btnError),
        ];
        break;
      case 2:
        buttons = [
          _buildBigButton(provider, '攻擊得分 Kill', EventCategory.attack, 'Kill', _btnSuccess),
          _buildBigButton(provider, '有效攻擊 InPlay', EventCategory.attack, 'InPlay', _btnNeutral),
          _buildBigButton(provider, '被攔回 Blocked', EventCategory.attack, 'BlockedCover', _btnNeutral),
          _buildBigButton(provider, '出界 Out', EventCategory.attack, 'Out', _btnError),
          _buildBigButton(provider, '被攔死 Stuffed', EventCategory.attack, 'BlockedDown', _btnError),
        ];
        break;
      case 3:
        buttons = [
          _buildBigButton(provider, '吊球得分', EventCategory.tip, 'Kill', _btnSuccess),
          _buildBigButton(provider, '有效吊球', EventCategory.tip, 'InPlay', _btnNeutral),
          _buildBigButton(provider, '吊球失誤', EventCategory.tip, 'Error', _btnError),
        ];
        break;
      case 4:
        buttons = [
          _buildBigButton(provider, '攔網得分', EventCategory.block, 'Kill', _btnSuccess),
          _buildBigButton(provider, '有效攔網', EventCategory.block, 'Touch', _btnNeutral),
          _buildBigButton(provider, '攔網失誤', EventCategory.block, 'Error', _btnError),
        ];
        break;
      case 5:
        buttons = [
          _buildBigButton(provider, '對方失誤 (送分)', EventCategory.oppError, 'Error', _btnSuccess),
          _buildBigButton(provider, '我方一般失誤', EventCategory.error, 'Fault', _btnError),
        ];
        break;
    }

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: buttons,
    );
  }

  Widget _buildBigButton(
    MatchProvider provider,
    String label,
    EventCategory category,
    String detail,
    Color color,
  ) {
    return ElevatedButton(
      onPressed: provider.isBusy
          ? null
          : () async {
              try {
                await provider.handleEvent(category: category, detailType: detail);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('紀錄失敗：$e'), backgroundColor: Colors.red),
                );
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildBottomBar(MatchProvider provider) {
    final lastLog = provider.lastEvent;
    var logText = "LOG: 尚無紀錄...";
    if (lastLog != null) {
      logText = "LOG: [${_getCategoryName(lastLog.category)}] ${lastLog.playerName} -> ${lastLog.detailType}";
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: Colors.black26,
      child: Row(
        children: [
          Expanded(
            child: Text(
              logText,
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ElevatedButton.icon(
            onPressed: provider.isBusy
                ? null
                : () async {
                    try {
                      await provider.undo();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Undo 失敗：$e'), backgroundColor: Colors.red),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
            icon: const Icon(Icons.undo, color: Colors.grey),
            label: const Text("Undo", style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent.withAlpha(50),
              elevation: 0,
            ),
            icon: const Icon(Icons.list, color: Colors.blueAccent),
            label: const Text("History", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void _showMatchControlMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _colBgPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('比賽進度控制', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.greenAccent),
              title: const Text('本局結束，設定下一局先發', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const StartingLineupScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.orangeAccent),
              title: const Text('比賽結束', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MatchSummaryScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showSubstitutionMenu(BuildContext context, MatchProvider provider) {
    final pos = _getSelectedPosition(provider);
    if (pos == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("請先點擊場上要被換下的球員！")));
      return;
    }

    final outPlayer = provider.selectedPlayer!;
    final bench = provider.benchPlayers;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '將 ${outPlayer.name} 換下，換上：',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(color: Colors.white24),
            if (bench.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('沒有板凳球員可換', style: TextStyle(color: Colors.white54)),
              ),
            ...bench.map(
              (p) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[800],
                  child: Text('${p.jerseyNo}', style: const TextStyle(color: Colors.white)),
                ),
                title: Text(p.name, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  provider.substitutePlayer(pos, p.id);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSmartTabSwitch(MatchProvider provider, CourtPosition pos) {
    final lastEvent = provider.lastEvent;
    if (lastEvent == null) return;

    final isFrontRow = [CourtPosition.p2, CourtPosition.p3, CourtPosition.p4].contains(pos);
    final isDeadBall = lastEvent.outcome != EventOutcome.neutral;

    setState(() {
      if (isDeadBall) {
        _selectedTabIndex = (provider.isOurServe && pos == CourtPosition.p1) ? 0 : 1;
      } else if (lastEvent.category == EventCategory.receive || lastEvent.detailType == 'BlockedCover') {
        _selectedTabIndex = 2;
      } else if (['InPlay', 'Good', 'Perfect'].contains(lastEvent.detailType)) {
        _selectedTabIndex = isFrontRow ? 4 : 1;
      }
    });
  }

  bool _isTabLocked(MatchProvider provider, int tabIndex) {
    final player = provider.selectedPlayer;
    if (player == null) return false;

    final pos = _getSelectedPosition(provider);
    if (pos == null) return false;

    final isFrontRow = [CourtPosition.p2, CourtPosition.p3, CourtPosition.p4].contains(pos);
    final isLibero = player.role == PlayerRole.libero;

    if (tabIndex == 0) return pos != CourtPosition.p1 || isLibero;
    if (tabIndex == 4) return !isFrontRow || isLibero;
    if (tabIndex == 2) return isLibero;
    return false;
  }

  CourtPosition? _getSelectedPosition(MatchProvider provider) {
    CourtPosition? pos;
    provider.positions.forEach((k, v) {
      if (v == provider.selectedPlayerId) pos = k;
    });
    return pos;
  }

  String _getCategoryName(EventCategory cat) => cat.name.toUpperCase();

  Widget _buildHistoryDrawer(MatchProvider provider) {
    return Drawer(
      backgroundColor: _colBgPanel,
      child: Column(
        children: [
          DrawerHeader(
            child: Center(
              child: Text(
                "SET ${provider.currentSet} 歷史紀錄",
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: provider.currentSetHistory.length,
              itemBuilder: (ctx, index) {
                final log = provider.currentSetHistory[index];
                final isPoint = log.outcome == EventOutcome.teamPoint;
                final isLoss = log.outcome == EventOutcome.oppPoint;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPoint ? Colors.blue : (isLoss ? Colors.red : Colors.grey[800]),
                    child: Text(
                      '${log.playerJerseyNo}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    "[${_getCategoryName(log.category)}] ${log.detailType}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${log.playerName}  |  比分: ${log.scoreTeamA} - ${log.scoreTeamB}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
