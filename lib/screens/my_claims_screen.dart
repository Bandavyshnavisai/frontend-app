import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../widgets/glass_box.dart';
import 'package:intl/intl.dart';

class MyClaimsScreen extends StatefulWidget {
  const MyClaimsScreen({super.key});

  @override
  State<MyClaimsScreen> createState() => _MyClaimsScreenState();
}

class _MyClaimsScreenState extends State<MyClaimsScreen> {
  List<dynamic> _claims = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClaims();
  }

  Future<void> _fetchClaims() async {
    setState(() => _isLoading = true);
    try {
      final claims = await ApiService.getMyClaims();
      if (mounted) {
        setState(() {
          _claims = claims;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load my claims: $e')));
      }
    }
  }

  String _formatDate(dynamic dateData) {
    if (dateData == null) return 'N/A';
    try {
      if (dateData is Map && dateData['_seconds'] != null) {
        final sec = dateData['_seconds'] as int;
        return DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(sec * 1000));
      }
      return DateFormat.yMMMd().format(DateTime.parse(dateData.toString()));
    } catch (_) {
      return 'Invalid date';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return Colors.white;
      case 'rejected': return Colors.white38;
      default: return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _claims.where((c) => c['status'] == 'pending').length;
    final approved = _claims.where((c) => c['status'] == 'approved').length;

    return Scaffold(
      appBar: AppBar(title: const Text('My Claims')),
      body: RefreshIndicator(
        onRefresh: _fetchClaims,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    // Stats Bar
                    Row(
                      children: [
                        _ClaimStatCard(icon: LucideIcons.package, label: 'Total', value: _claims.length.toString(), color: Colors.white),
                        const SizedBox(width: 10),
                        _ClaimStatCard(icon: LucideIcons.clock, label: 'Pending', value: pending.toString(), color: Colors.white70),
                        const SizedBox(width: 10),
                        _ClaimStatCard(icon: LucideIcons.checkCircle, label: 'Approved', value: approved.toString(), color: Colors.white),
                      ],
                    ).animate().fadeIn(delay: 50.ms).slideY(begin: -0.3),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Container(height: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16))),
                  ),
                  childCount: 3,
                ),
              )
            else if (_claims.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: GlassBox(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(LucideIcons.package, color: Colors.white12, size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text('No claims yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70)),
                        const SizedBox(height: 8),
                        const Text('Browse items and submit your first claim', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/'),
                          icon: const Icon(LucideIcons.arrowRight, size: 16),
                          label: const Text('Browse Items'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, idx) {
                      final claim = _claims[idx];
                      final item = claim['item'];
                      final status = claim['status'] ?? 'pending';
                      final statusColor = _statusColor(status);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.07)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  // Status left border
                                  Container(width: 4, color: statusColor.withOpacity(0.6)),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item != null ? item['title'] ?? 'Unknown Item' : 'Unknown Item',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: statusColor.withOpacity(0.5)),
                                                ),
                                                child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                                              ),
                                            ],
                                          ),
                                          if (item != null && item['description'] != null) ...[
                                            const SizedBox(height: 6),
                                            Text(item['description'], style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          ],
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(children: [
                                                const Icon(LucideIcons.calendar, size: 12, color: Colors.white38),
                                                const SizedBox(width: 4),
                                                Text(_formatDate(claim['createdAt']), style: const TextStyle(fontSize: 11, color: Colors.white38)),
                                              ]),
                                              if (status == 'pending')
                                                OutlinedButton.icon(
                                                  onPressed: () => context.push('/claims/${claim['id']}/chat'),
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  icon: const Icon(LucideIcons.messageSquare, size: 14),
                                                  label: const Text('Chat', style: TextStyle(fontSize: 12)),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: Duration(milliseconds: 80 * idx)).slideX(begin: -0.05),
                      );
                    },
                    childCount: _claims.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class _ClaimStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ClaimStatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassBox(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
