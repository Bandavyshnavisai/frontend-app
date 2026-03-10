import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../models/item.dart';
import '../widgets/glass_box.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Item> _items = [];
  bool _isLoading = true;
  String _filter = 'all';
  String _searchTerm = '';
  String? _buyingId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await ApiService.getItems(type: (_filter == 'all' || _filter == 'marketplace') ? null : _filter);
      if (mounted) {
        setState(() {
          if (_filter == 'marketplace') {
            _items = items.where((item) => item.saleStatus == 'listed').toList();
          } else {
            // Usually discovery only shows pending or approved items, except for marketplace
            _items = items.where((item) => item.saleStatus != 'listed' && item.saleStatus != 'sold' && item.saleStatus != 'reserved').toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load items: $e')));
      }
    }
  }

  Future<void> _handleClaim(String itemId) async {
    try {
      await ApiService.createClaim(itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim submitted successfully!')));
        context.push('/my-claims');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _handleBuy(String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2F),
        title: const Text('Confirm Purchase', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to purchase this item?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buy', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _buyingId = itemId);
    try {
      await ApiService.buyItem(itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase successful!')));
        _fetchItems();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  List<Item> get _filteredItems {
    if (_searchTerm.isEmpty) return _items;
    final q = _searchTerm.toLowerCase();
    return _items.where((i) =>
      i.title.toLowerCase().contains(q) || i.description.toLowerCase().contains(q)).toList();
  }

  String _formatDate(dynamic d) {
    if (d == null) return 'N/A';
    try {
      if (d is Map && d['_seconds'] != null) {
        return DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch((d['_seconds'] as int) * 1000));
      }
      return DateFormat.yMMMd().format(DateTime.parse(d.toString()));
    } catch (_) { return 'N/A'; }
  }

  @override
  Widget build(BuildContext context) {
    final lostCount = _items.where((i) => i.type == 'lost').length;
    final foundCount = _items.where((i) => i.type == 'found').length;
    final marketplaceCount = _items.where((i) => i.saleStatus == 'listed').length;
    final filtered = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Items Feed'),
        actions: [
          IconButton(icon: const Icon(LucideIcons.logOut), onPressed: () => context.go('/login'), tooltip: 'Sign out'),
          IconButton(icon: const Icon(LucideIcons.user), onPressed: () => context.push('/profile'), tooltip: 'Profile'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchItems,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Bar
                    Row(
                      children: [
                        _StatCard(icon: LucideIcons.package, label: 'Total', value: _items.length.toString(), color: Colors.white),
                        const SizedBox(width: 10),
                        _StatCard(icon: LucideIcons.trendingUp, label: 'Lost', value: lostCount.toString(), color: Colors.white70),
                        const SizedBox(width: 10),
                        _StatCard(icon: LucideIcons.eye, label: 'Found', value: foundCount.toString(), color: Colors.white38),
                      ],
                    ).animate().fadeIn(delay: 50.ms).slideY(begin: -0.3),
                    const SizedBox(height: 16),

                    // Search
                    GlassBox(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (v) => setState(() => _searchTerm = v),
                                  decoration: InputDecoration(
                                    hintText: 'Search items...',
                                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () => context.push('/report'),
                                icon: const Icon(LucideIcons.plus, size: 16),
                                label: const Text('Report'),
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Filters
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final f in ['all', 'lost', 'found', 'marketplace']) ...[
                                  _FilterChip(
                                    label: f.toUpperCase(),
                                    count: f == 'marketplace' ? marketplaceCount : (f == 'all' ? _items.length : (f == 'lost' ? lostCount : foundCount)),
                                    isSelected: _filter == f,
                                    onTap: () { setState(() => _filter = f); _fetchItems(); },
                                  ),
                                  if (f != 'marketplace') const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms),
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
                    child: Container(height: 200, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16))),
                  ),
                  childCount: 4,
                ),
              )
            else if (filtered.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: GlassBox(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(LucideIcons.package, color: Colors.white54, size: 32)),
                        const SizedBox(height: 16),
                        const Text('No items found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70)),
                        const SizedBox(height: 8),
                        const Text('Try adjusting your search or filters', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        const SizedBox(height: 20),
                        TextButton(onPressed: () { setState(() { _searchTerm = ''; _searchController.clear(); _filter = 'all'; }); _fetchItems(); },
                          child: const Text('Clear Filters')),
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
                      final item = filtered[idx];
                      return _ItemCard(
                        item: item,
                        formatDate: _formatDate,
                        onClaim: () => _handleClaim(item.id),
                        onBuy: () => _handleBuy(item.id),
                        onFindMatches: () => context.push(
                          '/items/${item.id}/matches',
                          extra: <String, String>{'title': item.title, 'type': item.type},
                        ),
                        isBuying: _buyingId == item.id,
                        delay: idx * 50,
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(currentIndex: 0),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassBox(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.count, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.black : Colors.white54),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Item item;
  final String Function(dynamic) formatDate;
  final VoidCallback onClaim;
  final VoidCallback onBuy;
  final VoidCallback onFindMatches;
  final bool isBuying;
  final int delay;

  const _ItemCard({required this.item, required this.formatDate, required this.onClaim, required this.onBuy, required this.onFindMatches, required this.isBuying, required this.delay});

  @override
  Widget build(BuildContext context) {
    final bool saleEligible = item.saleEligible;
    final dynamic price = item.price;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassBox(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / placeholder
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    Image.network(item.imageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder()),
                    Positioned.fill(child: Container(decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x990F0F1A)])))),
                    Positioned(top: 12, right: 12, child: _TypeBadge(type: item.type)),
                  ],
                ),
              ),
            ] else ...[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(children: [
                  _imagePlaceholder(height: 100),
                  Positioned(top: 10, right: 10, child: _TypeBadge(type: item.type)),
                ]),
              ),
            ],

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(item.description, style: const TextStyle(color: Colors.white54, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(LucideIcons.mapPin, size: 13, color: Colors.white38),
                    const SizedBox(width: 4),
                    Expanded(child: Text(item.location, style: const TextStyle(color: Colors.white38, fontSize: 12), overflow: TextOverflow.ellipsis)),
                    const Icon(LucideIcons.calendar, size: 13, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(formatDate(item.createdAt), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ]),
                  const SizedBox(height: 14),

                  // Action
                  if (item.status == 'pending') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(onPressed: onClaim, child: const Text('Claim This Item')),
                    ),
                  ],
                  if (saleEligible) ...[
                    const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isBuying ? null : onBuy,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                          icon: isBuying ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(LucideIcons.shoppingCart, size: 16),
                          label: Text(isBuying ? 'Processing...' : 'Buy · ₹${price ?? '?'}'),
                        ),
                      ),
                  ],
                  if (item.status == 'returned') ...[
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.06))),
                      child: const Text('✓ Already Returned', style: TextStyle(fontSize: 12, color: Colors.white38)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onFindMatches,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(LucideIcons.sparkles, size: 14, color: Colors.white70),
                      label: const Text('Find AI Matches', style: TextStyle(fontSize: 13, color: Colors.white70)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.1),
    );
  }

  Widget _imagePlaceholder({double height = 180}) => Container(
    height: height, width: double.infinity,
    color: Colors.white.withOpacity(0.03),
    child: const Center(child: Icon(LucideIcons.package, color: Colors.white12, size: 40)),
  );
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isLost = type == 'lost';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Text(type.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: LucideIcons.home, label: 'Home', isSelected: currentIndex == 0, onTap: () => context.go('/')),
              _NavItem(icon: LucideIcons.fileText, label: 'My Claims', isSelected: currentIndex == 1, onTap: () => context.push('/my-claims')),
              _NavItem(icon: LucideIcons.user, label: 'Profile', isSelected: currentIndex == 2, onTap: () => context.push('/profile')),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.white : Colors.white24, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.white24, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
