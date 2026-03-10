import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../widgets/glass_box.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> _pendingClaims = [];
  List<dynamic> _approvedClaims = [];
  List<dynamic> _rejectedClaims = [];
  List<dynamic> _marketplaceItems = [];

  bool _isPendingLoading = true;
  bool _isApprovedLoading = true;
  bool _isRejectedLoading = true;
  bool _isMarketplaceLoading = true;

  String? _pendingError;
  String? _approvedError;
  String? _rejectedError;
  String? _marketplaceError;

  Map<String, dynamic>? _analytics;
  bool _isAnalyticsLoading = true;
  bool _isSeeding = false;
  String? _seedMsg;
  String? _actionLoading; // Store claimId that is currently performing an action

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    _fetchPending();
    _fetchApproved();
    _fetchRejected();
    _fetchMarketplace();
    _fetchAnalytics();
  }

  Future<void> _fetchPending() async {
    setState(() => _isPendingLoading = true);
    try {
      final claims = await ApiService.getPendingClaims();
      if (mounted) setState(() { _pendingClaims = claims; _pendingError = null; });
    } catch (e) {
      if (mounted) setState(() => _pendingError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isPendingLoading = false);
    }
  }

  Future<void> _fetchApproved() async {
    setState(() => _isApprovedLoading = true);
    try {
      final claims = await ApiService.getClaimsByStatus('approved');
      if (mounted) setState(() { _approvedClaims = claims; _approvedError = null; });
    } catch (e) {
      if (mounted) setState(() => _approvedError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isApprovedLoading = false);
    }
  }

  Future<void> _fetchRejected() async {
    setState(() => _isRejectedLoading = true);
    try {
      final claims = await ApiService.getClaimsByStatus('rejected');
      if (mounted) setState(() { _rejectedClaims = claims; _rejectedError = null; });
    } catch (e) {
      if (mounted) setState(() => _rejectedError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isRejectedLoading = false);
    }
  }

  Future<void> _fetchMarketplace() async {
    setState(() => _isMarketplaceLoading = true);
    try {
      final items = await ApiService.getEligibleItemsForSale();
      if (mounted) setState(() { _marketplaceItems = items; _marketplaceError = null; });
    } catch (e) {
      if (mounted) setState(() => _marketplaceError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isMarketplaceLoading = false);
    }
  }

  Future<void> _fetchAnalytics() async {
    setState(() => _isAnalyticsLoading = true);
    try {
      final data = await ApiService.getClaimAnalytics();
      if (mounted) setState(() => _analytics = data);
    } catch (_) {
      // Ignore
    } finally {
      if (mounted) setState(() => _isAnalyticsLoading = false);
    }
  }

  Future<void> _handleAction(String claimId, Future<void> Function() action, String successMsg) async {
    setState(() => _actionLoading = claimId);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _actionLoading = null);
    }
  }

  Future<String?> _promptUser(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Submit', style: TextStyle(color: Color(0xFF8B5CF6)))),
        ],
      ),
    );
  }

  Future<void> _approveClaim(String claimId) async {
    final remarks = await _promptUser('Approve Claim', 'Enter remarks (optional)');
    if (remarks != null) await _handleAction(claimId, () => ApiService.approveClaim(claimId, remarks: remarks), 'Claim approved');
  }

  Future<void> _rejectClaim(String claimId) async {
    final remarks = await _promptUser('Reject Claim', 'Enter rejection reason');
    if (remarks != null && remarks.isNotEmpty) await _handleAction(claimId, () => ApiService.rejectClaim(claimId, remarks: remarks), 'Claim rejected');
  }

  Future<void> _reopenClaim(String claimId) async {
    await _handleAction(claimId, () => ApiService.reopenClaim(claimId), 'Claim reopened');
  }

  Future<void> _addNote(String claimId) async {
    final note = await _promptUser('Add Admin Note', 'Enter note text');
    if (note != null && note.isNotEmpty) await _handleAction(claimId, () => ApiService.addClaimNote(claimId, note), 'Note added');
  }

  Future<void> _viewEvidence(String claimId) async {
    setState(() => _actionLoading = claimId);
    try {
      final evidence = await ApiService.getClaimEvidence(claimId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            title: const Text('Evidence', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Text(evidence.toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load evidence', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _actionLoading = null);
    }
  }

  Future<void> _requestProof(String claimId) async {
    await _handleAction(claimId, () => ApiService.requestProof(claimId), 'Proof requested');
  }

  Future<void> _approveSale(String claimId, String itemId) async {
    final priceStr = await _promptUser('Approve Sale', 'Enter sale price');
    if (priceStr != null) {
      final price = double.tryParse(priceStr);
      if (price != null && price > 0) {
        await _handleAction(claimId, () => ApiService.approveSale(itemId, price), 'Item approved for sale');
      }
    }
  }

  Future<void> _seedCctv() async {
    setState(() { _isSeeding = true; _seedMsg = null; });
    try {
      await ApiService.seedCctvLogs();
      if (mounted) setState(() => _seedMsg = 'Seeded successfully');
    } catch (e) {
      if (mounted) setState(() => _seedMsg = 'Error: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  String _formatDate(dynamic dateData) {
    if (dateData == null) return 'N/A';
    try {
      DateTime dt;
      if (dateData is Map && dateData.containsKey('_seconds')) {
        dt = DateTime.fromMillisecondsSinceEpoch(dateData['_seconds'] * 1000);
      } else {
        dt = DateTime.parse(dateData.toString());
      }
      return DateFormat('M/d/yyyy').format(dt); // Matches "10/3/2026" web format
    } catch (_) {
      return dateData.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(LucideIcons.refreshCw, size: 20), onPressed: _fetchData),
          IconButton(icon: const Icon(LucideIcons.video, size: 20), onPressed: () => context.push('/cctv/logs')),
          IconButton(
            icon: const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 20),
            onPressed: () async {
              AuthState.logout();
              await FirebaseAuth.instance.signOut();
              if (mounted) context.go('/login');
            },
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
            Tab(text: 'Marketplace Setup'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent('pending', _pendingClaims, _isPendingLoading, _pendingError),
          _buildTabContent('approved', _approvedClaims, _isApprovedLoading, _approvedError),
          _buildTabContent('rejected', _rejectedClaims, _isRejectedLoading, _rejectedError),
          _buildMarketplaceTab(),
        ],
      ),
    );
  }

  Widget _buildMarketplaceTab() {
    return RefreshIndicator(
      onRefresh: _fetchMarketplace,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      const Icon(LucideIcons.store, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Text('Eligible for Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withAlpha(15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withAlpha(20))),
                        child: Text('${_marketplaceItems.length} ITEMS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
                      ),
                    ],
                  ).animate().fadeIn(),
                  const SizedBox(height: 8),
                  const Text('Items here are older than 30 days and have not been sold or claimed.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          if (_isMarketplaceLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_marketplaceError != null)
            SliverFillRemaining(child: Center(child: Text(_marketplaceError!, style: const TextStyle(color: Colors.red))))
          else if (_marketplaceItems.isEmpty)
             SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(LucideIcons.shoppingBag, size: 32, color: Colors.white38),
                    ),
                    const SizedBox(height: 16),
                    const Text('No Eligible Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text('No pending items older than 30 days', style: TextStyle(color: Colors.white38)),
                  ],
                ),
              ),
            )
          else 
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _marketplaceItems[index];
                    return _buildMarketplaceItemCard(item, index).animate().fadeIn(delay: Duration(milliseconds: index * 60)).slideY(begin: 0.1);
                  },
                  childCount: _marketplaceItems.length,
                ),
              ),
            ),
        ],
      )
    );
  }

  Widget _buildMarketplaceItemCard(Map<String, dynamic> item, int index) {
     final isLoading = _actionLoading == item['id'];
     
     return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item['title'] ?? 'Item', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(40)),
                ),
                child: Text((item['type'] ?? '').toString().toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (item['description'] != null)
            Text(item['description'], style: const TextStyle(fontSize: 12, color: Colors.white54), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          
          Row(
            children: [
              const Icon(LucideIcons.calendar, size: 12, color: Colors.white38),
              const SizedBox(width: 4),
              Text('Created: ${_formatDate(item['createdAt'])}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
               _buildPrimaryBtn('Set Price & Approve', LucideIcons.dollarSign, Colors.black, Colors.white, () => _approveSale(item['id'], item['id']), isLoading: isLoading),
            ]
          )
        ],
      )
     );
  }

  Widget _buildTabContent(String status, List<dynamic> claims, bool isLoading, String? error) {
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isSeeding ? null : _seedCctv,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isSeeding 
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(LucideIcons.database, size: 14),
                        label: Text(_isSeeding ? 'Seeding...' : 'Seed CCTV', style: const TextStyle(fontSize: 12)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withAlpha(15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withAlpha(20))),
                        child: Text('${claims.length} ${status.toUpperCase()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
                      ),
                    ],
                  ).animate().fadeIn(),

                  if (_seedMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withAlpha(20)),
                        ),
                        child: Text(_seedMsg!, style: const TextStyle(fontSize: 12, color: Colors.white)),
                      ),
                    ).animate().fadeIn().scale(),

                  const SizedBox(height: 24),

                  if (_isAnalyticsLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  else if (_analytics != null)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildStatCard('TOTAL CLAIMS', '${_analytics!['total'] ?? '-'}', LucideIcons.barChart3, Colors.white, width),
                            _buildStatCard('PENDING', '${_analytics!['pending'] ?? '-'}', LucideIcons.clock, Colors.white70, width),
                            _buildStatCard('APPROVED', '${_analytics!['approved'] ?? '-'}', LucideIcons.check, Colors.white, width),
                            _buildStatCard('REJECTED', '${_analytics!['rejected'] ?? '-'}', LucideIcons.x, Colors.white38, width),
                          ],
                        );
                      },
                    ).animate().slideY(begin: 0.1, end: 0).fadeIn(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          if (isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (error != null)
            SliverFillRemaining(child: Center(child: Text(error, style: const TextStyle(color: Colors.red))))
          else if (claims.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(LucideIcons.trendingUp, size: 32, color: Colors.white38),
                    ),
                    const SizedBox(height: 16),
                    const Text('All Clear!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('No $status claims', style: const TextStyle(color: Colors.white38)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final claim = claims[index];
                    return _buildClaimCard(claim, index, status).animate().fadeIn(delay: Duration(milliseconds: index * 60)).slideY(begin: 0.1);
                  },
                  childCount: claims.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Dark surface
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withAlpha(40))),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1))),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> claim, int index, String status) {
    final item = claim['item'] ?? {};
    final isMatchingFound = item['type'] == 'found';
    final isLoading = _actionLoading == claim['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Badge
          Row(
            children: [
              Expanded(child: Text(item['title'] ?? 'Item', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(40)),
                ),
                child: Text((item['type'] ?? '').toString().toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (item['description'] != null)
            Text(item['description'], style: const TextStyle(fontSize: 12, color: Colors.white54), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          
          // Date
          Row(
            children: [
              const Icon(LucideIcons.calendar, size: 12, color: Colors.white38),
              const SizedBox(width: 4),
              Text(_formatDate(claim['createdAt']), style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 16),

          // Primary Actions (Chat, Approve, Reject, Matches, CCTV)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPrimaryBtn('Chat', LucideIcons.messageSquare, Colors.white, Colors.white.withAlpha(20), () => context.push('/claims/${claim['id']}/chat')),
              if (status == 'pending') ...[
                _buildPrimaryBtn('Approve', LucideIcons.check, Colors.black, Colors.white, () => _approveClaim(claim['id']), isLoading: isLoading),
                _buildPrimaryBtn('Reject', LucideIcons.x, Colors.white, Colors.black, () => _rejectClaim(claim['id']), isLoading: isLoading),
              ],
              if (claim['itemId'] != null)
                _buildPrimaryBtn('AI Match', LucideIcons.sparkles, Colors.white, Colors.white.withAlpha(20), () => context.push('/items/${claim['itemId']}/matches?collection=${isMatchingFound ? 'foundItems' : 'lostItems'}')),
              if (claim['itemId'] != null)
                _buildPrimaryBtn('CCTV', LucideIcons.video, Colors.white, Colors.white.withAlpha(20), () => context.push('/claims/${claim['id']}/cctv')),
            ],
          ),

          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Colors.white10)),

          // Secondary Actions (Reopen, Note, Evidence, Proof, Sale)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (status != 'pending')
                _buildSecondaryBtn('Reopen', LucideIcons.rotateCcw, () => _reopenClaim(claim['id']), isLoading: isLoading),
              _buildSecondaryBtn('Note', LucideIcons.stickyNote, () => _addNote(claim['id']), isLoading: isLoading),
              _buildSecondaryBtn('Evidence', LucideIcons.fileSearch, () => _viewEvidence(claim['id']), isLoading: isLoading),
              _buildSecondaryBtn('Proof', LucideIcons.shieldAlert, () => _requestProof(claim['id']), isLoading: isLoading),
              if (claim['itemId'] != null && status == 'approved')
                _buildSecondaryBtn('Sale', LucideIcons.dollarSign, () => _approveSale(claim['id'], claim['itemId']), isLoading: isLoading, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildPrimaryBtn(String label, IconData icon, Color color, Color bgColor, VoidCallback onTap, {bool isLoading = false}) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isLoading ? Colors.transparent : bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isLoading ? Colors.white10 : color.withAlpha(50)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38))
            else Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isLoading ? Colors.white38 : color)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryBtn(String label, IconData icon, VoidCallback onTap, {bool isLoading = false, Color? color}) {
    final c = color ?? Colors.white54;
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isLoading ? Colors.white24 : c),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: isLoading ? Colors.white24 : c)),
          ],
        ),
      ),
    );
  }
}
