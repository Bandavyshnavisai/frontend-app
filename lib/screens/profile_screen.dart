import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../widgets/glass_box.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Profile state
  Map<String, dynamic>? _profile;
  bool _profileLoading = true;
  bool _saving = false;
  String _successMsg = '';
  String? _saveError;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // My Items state
  List<dynamic> _myItems = [];
  bool _itemsLoading = true;
  String? _editingItemId;
  final _editTitleCtrl = TextEditingController();
  final _editLocationCtrl = TextEditingController();
  final _editDescCtrl = TextEditingController();
  bool _editLoading = false;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchMyItems();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _editTitleCtrl.dispose();
    _editLocationCtrl.dispose();
    _editDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await ApiService.getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _nameController.text = profile['displayName'] ?? '';
          _phoneController.text = profile['phoneNumber'] ?? '';
          _profileLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _fetchMyItems() async {
    setState(() => _itemsLoading = true);
    try {
      final items = await ApiService.getMyItems();
      if (mounted) setState(() { _myItems = items; _itemsLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _itemsLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() { _saving = true; _saveError = null; _successMsg = ''; });
    try {
      await ApiService.updateProfile({'displayName': _nameController.text.trim(), 'phoneNumber': _phoneController.text.trim()});
      if (mounted) {
        setState(() { _successMsg = 'Profile updated successfully!'; _saving = false; });
        Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _successMsg = ''); });
      }
    } catch (e) {
      if (mounted) setState(() { _saveError = 'Failed to update profile. Please try again.'; _saving = false; });
    }
  }

  void _startEditing(dynamic item) {
    setState(() {
      _editingItemId = item['id'];
      _editTitleCtrl.text = item['title'] ?? '';
      _editLocationCtrl.text = item['location'] ?? '';
      _editDescCtrl.text = item['description'] ?? '';
    });
  }

  void _cancelEditing() => setState(() { _editingItemId = null; });

  Future<void> _saveItem(String itemId) async {
    setState(() => _editLoading = true);
    try {
      await ApiService.updateItem(itemId, {
        'title': _editTitleCtrl.text.trim(),
        'location': _editLocationCtrl.text.trim(),
        'description': _editDescCtrl.text.trim(),
      });
      setState(() { _editingItemId = null; _editLoading = false; });
      await _fetchMyItems();
    } catch (e) {
      if (mounted) { setState(() => _editLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Delete Item', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this item?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deletingId = itemId);
    try {
      await ApiService.deleteItem(itemId);
      await _fetchMyItems();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.logOut, color: Colors.white38),
            onPressed: () async { 
              AuthState.logout();
              await FirebaseAuth.instance.signOut(); 
              if (mounted) context.go('/login'); 
            },
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: _profileLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async { await _fetchProfile(); await _fetchMyItems(); },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar Card
                  GlassBox(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(LucideIcons.user, color: Colors.white, size: 36),
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                width: 20, height: 20,
                                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black, width: 2)),
                                child: const Icon(LucideIcons.check, color: Colors.white, size: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_profile?['displayName'] ?? user?.displayName ?? 'User', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text((_profile?['role'] ?? 'member').toString().toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w500, letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 50.ms).slideY(begin: -0.2),
                  const SizedBox(height: 16),

                  // Account Details
                  GlassBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ACCOUNT', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white38, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 14),
                        _AccountRow(icon: LucideIcons.mail, iconColor: Colors.white70, text: _profile?['email'] ?? user?.email ?? ''),
                        const SizedBox(height: 10),
                        _AccountRow(icon: LucideIcons.creditCard, iconColor: Colors.white60, text: () {
                          final campusId = _profile?['campusId'];
                          if (campusId != null) return campusId.toString();
                          final uid = (_profile?['uid'] ?? '').toString();
                          return uid.length > 8 ? uid.substring(0, 8) : uid;
                        }()),
                        const SizedBox(height: 10),
                        _AccountRow(icon: LucideIcons.shield, iconColor: Colors.white38, text: '${_profile?['role'] ?? 'member'} Account'),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 16),

                  // Personal Info Form
                  GlassBox(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                          child: Row(
                            children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Personal Information', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white)),
                                Text('Update your public profile', style: TextStyle(fontSize: 11, color: Colors.white38)),
                              ])),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 24),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_successMsg.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.2))),
                                  child: Row(children: [const Icon(LucideIcons.check, color: Colors.white, size: 14), const SizedBox(width: 8), Text(_successMsg, style: const TextStyle(color: Colors.white, fontSize: 12))]),
                                ),
                                const SizedBox(height: 14),
                              ],
                              if (_saveError != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.1))),
                                  child: Text(_saveError!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ),
                                const SizedBox(height: 14),
                              ],
                              const Text('Full Name', style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 6),
                              TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Enter your name')),
                              const SizedBox(height: 14),
                              const Text('Phone Number (Optional)', style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 6),
                              TextField(controller: _phoneController, decoration: const InputDecoration(hintText: '+91 XXXXXXXXXX'), keyboardType: TextInputType.phone),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _saveProfile,
                              icon: _saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(LucideIcons.save, size: 16),
                              label: Text(_saving ? 'Saving...' : 'Save Changes'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 24),

                  // My Reported Items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('My Reported Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.08))),
                        child: Text('${_myItems.length} items', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 12),

                  if (_itemsLoading)
                    ...List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(height: 80, decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14))),
                    ))
                  else if (_myItems.isEmpty)
                    GlassBox(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)), child: const Icon(LucideIcons.package, color: Colors.white12, size: 28)),
                          const SizedBox(height: 12),
                          const Text("You haven't reported any items yet.", style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ],
                      ),
                    ).animate().fadeIn(delay: 250.ms)
                  else
                    ...List.generate(_myItems.length, (idx) {
                      final item = _myItems[idx];
                      final isEditing = _editingItemId == item['id'];
                      final isDeleting = _deletingId == item['id'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassBox(
                          child: isEditing
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(controller: _editTitleCtrl, decoration: const InputDecoration(hintText: 'Title', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
                                  const SizedBox(height: 8),
                                  TextField(controller: _editLocationCtrl, decoration: const InputDecoration(hintText: 'Location', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
                                  const SizedBox(height: 8),
                                  TextField(controller: _editDescCtrl, maxLines: 2, decoration: const InputDecoration(hintText: 'Description', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    ElevatedButton.icon(
                                      onPressed: _editLoading ? null : () => _saveItem(item['id']),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                                      icon: _editLoading ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(LucideIcons.check, size: 14),
                                      label: const Text('Save', style: TextStyle(fontSize: 12)),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: _cancelEditing,
                                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                                      icon: const Icon(LucideIcons.x, size: 14),
                                      label: const Text('Cancel', style: TextStyle(fontSize: 12)),
                                    ),
                                  ]),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Expanded(child: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          const SizedBox(width: 6),
                                          _SmallBadge(text: item['type'] ?? '', isLost: item['type'] == 'lost'),
                                          const SizedBox(width: 4),
                                          _SmallBadge(text: item['status'] ?? '', isLost: item['status'] == 'pending'),
                                        ]),
                                        const SizedBox(height: 4),
                                        Text(item['description'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          const Icon(LucideIcons.mapPin, size: 11, color: Colors.white30),
                                          const SizedBox(width: 4),
                                          Text(item['location'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white30)),
                                        ]),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      IconButton(
                                        onPressed: () => _startEditing(item),
                                        icon: const Icon(LucideIcons.pencil, size: 16, color: Colors.white38),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        onPressed: isDeleting ? null : () => _deleteItem(item['id']),
                                        icon: isDeleting
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(LucideIcons.trash2, size: 16, color: Colors.white24),
                                        tooltip: 'Delete',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                        ).animate().fadeIn(delay: Duration(milliseconds: 60 * idx)),
                      );
                    }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  const _AccountRow({required this.icon, required this.iconColor, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: iconColor, size: 15)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
    ],
  );
}

class _SmallBadge extends StatelessWidget {
  final String text;
  final bool isLost;
  const _SmallBadge({required this.text, required this.isLost});

  @override
  Widget build(BuildContext context) {
    const color = Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}
