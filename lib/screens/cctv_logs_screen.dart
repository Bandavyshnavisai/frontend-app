import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/glass_box.dart';

/// Displays raw CCTV log entries from the `cctvLogs` Firestore collection.
///
/// Each entry has: zone (String), timestamp (ISO string), objects (List<String>)
/// This screen is admin-only — navigate here from the Admin panel.
class CctvLogsScreen extends StatefulWidget {
  const CctvLogsScreen({super.key});

  @override
  State<CctvLogsScreen> createState() => _CctvLogsScreenState();
}

class _CctvLogsScreenState extends State<CctvLogsScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String? _error;

  // Known campus zones for the filter chips
  final List<String> _zones = [];
  String? _selectedZone;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final logs = await ApiService.getCctvLogs(zone: _selectedZone);
      if (mounted) {
        // Extract distinct zones for filter chips
        final zoneSet = <String>{};
        for (final log in logs) {
          if (log['zone'] != null) zoneSet.add(log['zone'].toString());
        }
        setState(() {
          _logs = logs;
          _isLoading = false;
          if (_zones.isEmpty) {
            _zones.addAll(zoneSet.toList()..sort());
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  String _fmtTimestamp(dynamic ts) {
    if (ts == null) return 'N/A';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) { return ts.toString(); }
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      return DateFormat('EEEE, d MMMM yyyy').format(dt);
    } catch (_) { return ''; }
  }

  Color _zoneColor(String? zone) {
    if (zone == null) return Colors.white38;
    // Map zones to fixed grayscale values for consistency
    final shades = [
      Colors.white,
      Colors.white70,
      Colors.white60,
      Colors.white54,
      Colors.white38,
      Colors.white30,
      Colors.white24,
      Colors.white12,
    ];
    return shades[zone.hashCode.abs() % shades.length];
  }

  @override
  Widget build(BuildContext context) {
    // Group logs by date
    final grouped = <String, List<dynamic>>{};
    for (final log in _logs) {
      final dateKey = _fmtDate(log['timestamp']);
      grouped.putIfAbsent(dateKey, () => []).add(log);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CCTV Logs'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: _fetchLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Zone filter chips
          if (_zones.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _ZoneChip(label: 'All Zones', isSelected: _selectedZone == null, color: const Color(0xFF6366F1),
                    onTap: () { setState(() => _selectedZone = null); _fetchLogs(); }),
                  ...(_zones.map((z) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _ZoneChip(label: z, isSelected: _selectedZone == z, color: _zoneColor(z),
                      onTap: () { setState(() => _selectedZone = z); _fetchLogs(); }),
                  ))),
                ],
              ),
            ).animate().fadeIn(),

          const Divider(height: 1, color: Color(0x1AFFFFFF)),

          // Stats row
          if (!_isLoading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GlassBox(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MiniStat(label: 'Total Logs', value: _logs.length.toString(), icon: LucideIcons.video, color: Colors.white),
                    _MiniStat(label: 'Zones', value: _zones.length.toString(), icon: LucideIcons.mapPin, color: Colors.white70),
                    _MiniStat(label: 'Days', value: grouped.keys.length.toString(), icon: LucideIcons.calendar, color: Colors.white38),
                  ],
                ),
              ).animate().fadeIn(delay: 50.ms),
            ),

          const SizedBox(height: 12),

          // Content
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.video, color: Colors.white12, size: 48),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton(onPressed: _fetchLogs, child: const Text('Retry')),
                      ],
                    )))
              : _logs.isEmpty
                ? const Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.video, color: Colors.white12, size: 48),
                      SizedBox(height: 16),
                      Text('No CCTV logs found', style: TextStyle(color: Colors.white38, fontSize: 14)),
                      SizedBox(height: 6),
                      Text('Seed logs from the Admin panel', style: TextStyle(color: Colors.white24, fontSize: 12)),
                    ],
                  ))
                : RefreshIndicator(
                    onRefresh: _fetchLogs,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: grouped.entries.toList().asMap().entries.map((mapEntry) {
                        final groupIdx = mapEntry.key;
                        final dateLabel = mapEntry.value.key;
                        final entries = mapEntry.value.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date divider
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(20),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withAlpha(40)),
                                    ),
                                    child: Text(dateLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Container(height: 1, color: Colors.white.withAlpha(12))),
                                ],
                              ),
                            ).animate().fadeIn(delay: Duration(milliseconds: groupIdx * 50)),

                            // Log entries for this date
                            ...entries.asMap().entries.map((e) {
                              final idx = e.key;
                              final log = e.value;
                              final zone = log['zone']?.toString();
                              final objects = (log['objects'] as List?)?.cast<String>() ?? [];
                              final zoneColor = _zoneColor(zone);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Timeline line + dot
                                    SizedBox(
                                      width: 40,
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 12, height: 12,
                                            decoration: BoxDecoration(
                                              color: zoneColor,
                                              shape: BoxShape.circle,
                                              boxShadow: [BoxShadow(color: zoneColor.withAlpha(100), blurRadius: 6, spreadRadius: 1)],
                                            ),
                                          ),
                                          Container(width: 2, height: 80, color: Colors.white.withAlpha(10)),
                                        ],
                                      ),
                                    ),

                                    // Card
                                    Expanded(
                                      child: GlassBox(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Time + Zone
                                            Row(
                                              children: [
                                                const Icon(LucideIcons.clock, size: 12, color: Colors.white38),
                                                const SizedBox(width: 4),
                                                Text(_fmtTimestamp(log['timestamp']), style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500)),
                                                const Spacer(),
                                                if (zone != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: zoneColor.withAlpha(30),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: zoneColor.withAlpha(80)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(LucideIcons.mapPin, size: 10, color: zoneColor),
                                                        const SizedBox(width: 4),
                                                        Text(zone, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: zoneColor)),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // Detected objects
                                            if (objects.isEmpty)
                                              const Text('No objects detected', style: TextStyle(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.italic))
                                            else
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: objects.map((obj) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withAlpha(10),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.white.withAlpha(20)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(LucideIcons.eye, size: 10, color: Colors.white38),
                                                      const SizedBox(width: 4),
                                                      Text(obj, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                                    ],
                                                  ),
                                                )).toList(),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(delay: Duration(milliseconds: (groupIdx * 50) + (idx * 30))).slideX(begin: 0.05);
                            }),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ZoneChip({required this.label, required this.isSelected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? color.withAlpha(40) : Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? color.withAlpha(120) : Colors.white.withAlpha(20)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? color : Colors.white38)),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      ]),
    ],
  );
}
