import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class MatchDashboardScreen extends StatefulWidget {
  final String? matchId;
  final List<dynamic>? livePlayLogs;
  final Map<String, dynamic>? liveMatchInfo;

  const MatchDashboardScreen({
    super.key,
    this.matchId,
    this.livePlayLogs,
    this.liveMatchInfo,
  });

  @override
  State<MatchDashboardScreen> createState() => _MatchDashboardScreenState();
}

class _MatchDashboardScreenState extends State<MatchDashboardScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _playerStats = [];
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.matchId != null && widget.matchId!.isNotEmpty) {
        final dashboard = await ApiService.fetchDashboard(widget.matchId!);
        if (!mounted) return;
        setState(() {
          _playerStats = dashboard;
          _logs = widget.livePlayLogs ?? [];
          _isLoading = false;
        });
        return;
      }

      final logs = widget.livePlayLogs ?? [];
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _playerStats = _buildStatsFromLogs(logs);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final logs = widget.livePlayLogs ?? [];
        _logs = logs;
        _playerStats = _buildStatsFromLogs(logs);
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _buildStatsFromLogs(List<dynamic> logs) {
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final raw in logs) {
      final log = Map<String, dynamic>.from(raw as Map);
      final playerId = log['player_id']?.toString() ?? '';
      grouped.putIfAbsent(
        playerId,
        () => {
          'player_id': playerId,
          'player_name': log['player_name'] ?? 'Unknown',
          'jersey_no': log['jersey_no'] ?? 0,
          'total_actions': 0,
          'kills': 0,
          'aces': 0,
          'blocks': 0,
          'errors': 0,
        },
      );
      grouped[playerId]!['total_actions'] = (grouped[playerId]!['total_actions'] as int) + 1;
      if (log['action_type'] == 'attack' && log['action_result'] == 'Kill') {
        grouped[playerId]!['kills'] = (grouped[playerId]!['kills'] as int) + 1;
      }
      if (log['action_type'] == 'serve' && log['action_result'] == 'Ace') {
        grouped[playerId]!['aces'] = (grouped[playerId]!['aces'] as int) + 1;
      }
      if (log['action_type'] == 'block' && log['action_result'] == 'Kill') {
        grouped[playerId]!['blocks'] = (grouped[playerId]!['blocks'] as int) + 1;
      }
      if (['Error', 'Fault', 'Out', 'BlockedDown'].contains(log['action_result'])) {
        grouped[playerId]!['errors'] = (grouped[playerId]!['errors'] as int) + 1;
      }
    }
    return grouped.values.toList();
  }

  List<PieChartSectionData> _buildPieSections() {
    final totalKills = _playerStats.fold<int>(0, (sum, item) => sum + ((item['kills'] ?? 0) as int));
    final totalAces = _playerStats.fold<int>(0, (sum, item) => sum + ((item['aces'] ?? 0) as int));
    final totalBlocks = _playerStats.fold<int>(0, (sum, item) => sum + ((item['blocks'] ?? 0) as int));
    final totalErrors = _playerStats.fold<int>(0, (sum, item) => sum + ((item['errors'] ?? 0) as int));

    final values = [
      {'title': 'Kill', 'value': totalKills, 'color': Colors.blue},
      {'title': 'Ace', 'value': totalAces, 'color': Colors.orange},
      {'title': 'Block', 'value': totalBlocks, 'color': Colors.green},
      {'title': 'Error', 'value': totalErrors, 'color': Colors.redAccent},
    ].where((item) => (item['value'] as int) > 0).toList();

    if (values.isEmpty) {
      return [
        PieChartSectionData(
          value: 1,
          title: 'No Data',
          color: Colors.grey,
          radius: 70,
        ),
      ];
    }

    return values
        .map(
          (item) => PieChartSectionData(
            value: (item['value'] as int).toDouble(),
            title: '${item['title']}\n${item['value']}',
            color: item['color'] as Color,
            radius: 70,
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        )
        .toList();
  }

  List<BarChartGroupData> _buildBarGroups() {
    for (var i = 0; i < _playerStats.length; i++) {}
    return List.generate(_playerStats.length, (index) {
      final item = _playerStats[index];
      final total = ((item['kills'] ?? 0) as int) +
          ((item['aces'] ?? 0) as int) +
          ((item['blocks'] ?? 0) as int);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: total.toDouble(),
            width: 18,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final matchInfo = widget.liveMatchInfo ?? const <String, dynamic>{};

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('數據報表'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: const Color(0xFF161B22),
                  child: ListTile(
                    title: Text(
                      '對手：${matchInfo['opponent_name'] ?? '-'}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '局數 ${matchInfo['our_sets_won'] ?? 0} : ${matchInfo['opponent_sets_won'] ?? 0}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('得分結構', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: Card(
                    color: const Color(0xFF161B22),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: PieChart(PieChartData(sections: _buildPieSections(), centerSpaceRadius: 32)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('球員產出', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 280,
                  child: Card(
                    color: const Color(0xFF161B22),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                      child: BarChart(
                        BarChartData(
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index < 0 || index >= _playerStats.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '${_playerStats[index]['jersey_no'] ?? 0}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: true),
                          barGroups: _buildBarGroups(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFF161B22),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('號碼', style: TextStyle(color: Colors.white70))),
                        DataColumn(label: Text('姓名', style: TextStyle(color: Colors.white70))),
                        DataColumn(label: Text('總動作', style: TextStyle(color: Colors.white70))),
                        DataColumn(label: Text('Kill', style: TextStyle(color: Colors.white70))),
                        DataColumn(label: Text('Ace', style: TextStyle(color: Colors.white70))),
                        DataColumn(label: Text('Block', style: TextStyle(color: Colors.white70))),
                        DataColumn(label: Text('Error', style: TextStyle(color: Colors.white70))),
                      ],
                      rows: _playerStats
                          .map(
                            (item) => DataRow(
                              cells: [
                                DataCell(Text('${item['jersey_no'] ?? 0}', style: const TextStyle(color: Colors.white))),
                                DataCell(Text('${item['player_name'] ?? ''}', style: const TextStyle(color: Colors.white))),
                                DataCell(Text('${item['total_actions'] ?? 0}', style: const TextStyle(color: Colors.white))),
                                DataCell(Text('${item['kills'] ?? 0}', style: const TextStyle(color: Colors.white))),
                                DataCell(Text('${item['aces'] ?? 0}', style: const TextStyle(color: Colors.white))),
                                DataCell(Text('${item['blocks'] ?? 0}', style: const TextStyle(color: Colors.white))),
                                DataCell(Text('${item['errors'] ?? 0}', style: const TextStyle(color: Colors.white))),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
