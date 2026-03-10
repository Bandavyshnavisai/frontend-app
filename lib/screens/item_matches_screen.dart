import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../services/api_service.dart';
import '../widgets/glass_box.dart';

/// A full-screen AI matching flow that mimics the web AdminMatches page.
/// Pass [itemId] and [itemType] ('lost' or 'found') when navigating here.
class ItemMatchesScreen extends StatefulWidget {
  final String itemId;
  final String itemTitle;
  final String itemType; // 'lost' or 'found'

  const ItemMatchesScreen({
    super.key,
    required this.itemId,
    required this.itemTitle,
    required this.itemType,
  });

  @override
  State<ItemMatchesScreen> createState() => _ItemMatchesScreenState();
}

class _ItemMatchesScreenState extends State<ItemMatchesScreen> {
  int _step = 0; // 0 = fresh, 1 = features extracted, 2 = suggestions loaded
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? _features;
  List<dynamic>? _suggestions;
  Map<String, dynamic>? _customComparisonResult;
  final ImagePicker _picker = ImagePicker();

  String get _collection =>
      widget.itemType == 'lost' ? 'lostItems' : 'foundItems';

  Future<void> _extractFeatures() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.extractFeatures(widget.itemId, _collection);
      if (mounted) {
        setState(() {
          _step = 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _compareAndSuggest() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await ApiService.compareAndSuggestFull(widget.itemId, _collection);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _step = 2;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _uploadAndCompare() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;
      
      setState(() { _loading = true; _error = null; });
      
      final bytes = await image.readAsBytes();
      final String base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
      
      final result = await ApiService.compareCustomImage(widget.itemId, base64Image);
      
      if (mounted) {
        setState(() {
          _customComparisonResult = result;
          _step = 3;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Comparison failed: ${e.toString().replaceFirst('Exception: ', '')}'; _loading = false; });
    }
  }

  Color _scoreColor(double score) {
    if (score >= 0.7) return Colors.white;
    if (score >= 0.5) return Colors.white70;
    return Colors.white38;
  }

  String _scoreBadge(double score) {
    if (score >= 0.7) return 'HIGH';
    if (score >= 0.5) return 'MEDIUM';
    return 'LOW';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Match Suggestions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.itemTitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item info chip
            GlassBox(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withAlpha(40)),
                    ),
                    child: Text(widget.itemType.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('ID: ${widget.itemId}', style: const TextStyle(color: Colors.white54, fontSize: 11), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ).animate().fadeIn(),
            const SizedBox(height: 16),

            // Step Progress Bar
            _StepBar(currentStep: _step).animate().fadeIn(delay: 50.ms),
            const SizedBox(height: 16),

            // Error banner
            if (_error != null)
              GlassBox(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(LucideIcons.xCircle, color: Colors.white60, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white60, fontSize: 13))),
                  ],
                ),
              ).animate().fadeIn(),

            // Loading card
            if (_loading)
              GlassBox(
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFF6366F1).withAlpha(30), borderRadius: BorderRadius.circular(10)),
                      child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF6366F1)))),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _step == 0 ? 'Analyzing image...' : (_step == 3 && _loading ? 'Comparing uploaded image...' : 'Comparing against all items...'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                        const Text('This may take a moment', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(),

            // ── Step 1: Extract Features ──
            const SizedBox(height: 4),
            _StepCard(
              icon: LucideIcons.cpu,
              iconColor: Colors.white70,
              title: 'Feature Extraction',
              subtitle: 'Groq Vision AI analyzes your item\'s image and extracts visual descriptors.',
              isDone: _step >= 1,
              isActive: _step == 0,
              actionLabel: 'Extract Features',
              actionIcon: LucideIcons.zap,
              onAction: _loading ? null : _extractFeatures,
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 12),

            // ── Step 2: Compare & Suggest ──
            _StepCard(
              icon: LucideIcons.search,
              iconColor: Colors.white60,
              title: 'Compare & Suggest',
              subtitle: 'Compares this ${widget.itemType} item against all ${widget.itemType == 'lost' ? 'found' : 'lost'} items with extracted features.',
              isDone: _step >= 2,
              isActive: _step == 1,
              actionLabel: 'Find Matches',
              actionIcon: LucideIcons.sparkles,
              onAction: _step < 1 || _loading ? null : _compareAndSuggest,
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 12),
            
            // ── Step 3: Custom Upload ──
             _StepCard(
              icon: LucideIcons.image,
              iconColor: Colors.white38,
              title: 'Compare Custom Image',
              subtitle: 'Upload a picture to check its similarity against THIS item.',
              isDone: _customComparisonResult != null,
              isActive: _step >= 1, // Available as soon as features are extracted
              actionLabel: 'Upload Image',
              actionIcon: LucideIcons.uploadCloud,
              onAction: _step < 1 || _loading ? null : _uploadAndCompare,
            ).animate().fadeIn(delay: 200.ms),

            // ── Custom Image Results ──
            if (_customComparisonResult != null) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(LucideIcons.image, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  const Text('Custom Image Result', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                ],
              ).animate().fadeIn(),
              const SizedBox(height: 12),
              _buildResultCard(_customComparisonResult!, 0, isCustom: true),
            ],

            // ── Results ──
            if (_step >= 2 && _suggestions != null) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(LucideIcons.sparkles, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text('Top Matches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(12), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withAlpha(20))),
                    child: Text('${_suggestions!.length} result${_suggestions!.length != 1 ? 's' : ''}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  ),
                ],
              ).animate().fadeIn(),
              const SizedBox(height: 12),

              if (_suggestions!.isEmpty)
                GlassBox(
                  padding: const EdgeInsets.all(40),
                  child: const Column(
                    children: [
                      Icon(LucideIcons.searchX, color: Colors.white12, size: 40),
                      SizedBox(height: 12),
                      Text('No matching items found above threshold.', style: TextStyle(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center),
                    ],
                  ),
                ).animate().fadeIn()
              else
                ...List.generate(_suggestions!.length, (idx) {
                  final s = _suggestions![idx];
                  return _buildResultCard(s, idx, isCustom: false);
                }),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _buildResultCard(Map<String, dynamic> s, int idx, {required bool isCustom}) {
    final score = (s['score'] as num?)?.toDouble() ?? 0.0;
    final matching = (s['matchingAttributes'] as List?)?.cast<String>() ?? [];
    final mismatched = (s['mismatchedAttributes'] as List?)?.cast<String>() ?? [];
    final scoreColor = _scoreColor(score);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: rank + title + badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCustom)
                  Container(
                    width: 32, height: 32,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(12), borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('#${idx + 1}', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12))),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isCustom ? "Comparison with: ${widget.itemTitle}" : (s['title'] ?? s['itemId'] ?? ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                      if (!isCustom && s['description'] != null && s['description'].toString().isNotEmpty)
                        Text(s['description'], style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scoreColor.withAlpha(100)),
                  ),
                  child: Text(_scoreBadge(score), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: scoreColor)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Score progress bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Match Score', style: TextStyle(fontSize: 11, color: Colors.white38)),
                Text('${(score * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: score.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white.withAlpha(12),
                valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              ),
            ),

            // Meta
             if (!isCustom && (s['zone'] != null || s['reportedDate'] != null)) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (s['zone'] != null) ...[
                    const Icon(LucideIcons.mapPin, size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(s['zone'], style: const TextStyle(fontSize: 11, color: Colors.white38)),
                    const SizedBox(width: 12),
                  ],
                  if (s['reportedDate'] != null) ...[
                    const Icon(LucideIcons.calendar, size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(s['reportedDate'].toString().substring(0, 10), style: const TextStyle(fontSize: 11, color: Colors.white38)),
                  ],
                ],
              ),
            ],

            // Attribute chips
            if (matching.isNotEmpty || mismatched.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...matching.map((a) => _AttributeChip(label: '✓ $a', color: Colors.white)),
                  ...mismatched.map((a) => _AttributeChip(label: '✗ $a', color: Colors.white38)),
                ],
              ),
            ],

            // Image (if present)
            if (!isCustom && s['imageUrl'] != null && s['imageUrl'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  s['imageUrl'],
                  height: 140, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 80, color: Colors.white.withAlpha(8), child: const Center(child: Icon(LucideIcons.image, color: Colors.white12))),
                ),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: 80 * idx)).slideY(begin: 0.1),
    );
  }
}

class _StepBar extends StatelessWidget {
  final int currentStep;
  const _StepBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const steps = ['Extract Features', 'Compare & Suggest'];
    return Row(
      children: List.generate(steps.length, (i) {
        final done = currentStep > i;
        final active = currentStep == i;
        return Expanded(
          child: Row(
            children: [
              if (i > 0) Container(height: 2, width: 20, color: Colors.white.withAlpha(done ? 120 : 25)),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(done ? 30 : active ? 12 : 6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withAlpha(done ? 80 : 15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(done ? LucideIcons.checkCircle : (i == 0 ? LucideIcons.eye : LucideIcons.search),
                        size: 14, color: done ? Colors.white : active ? Colors.white70 : Colors.white30),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${i + 1}. ${steps[i]}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: done ? Colors.white70 : active ? Colors.white70 : Colors.white30), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _StepCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDone;
  final bool isActive;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  const _StepCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.isActive,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDone || isActive ? 1.0 : 0.4,
      child: GlassBox(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconColor.withAlpha(25), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isDone)
              const Icon(LucideIcons.checkCircle, color: Colors.white, size: 22)
            else
              ElevatedButton.icon(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                icon: Icon(actionIcon, size: 14, color: Colors.black),
                label: Text(actionLabel, style: const TextStyle(color: Colors.black)),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttributeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _AttributeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withAlpha(80)),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.withAlpha(220))),
  );
}
