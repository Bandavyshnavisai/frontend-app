import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/glass_box.dart';

/// CCTV Verification screen — accessible from a claim's chat screen or admin panel.
/// Shows: saved AI verdict + ability to run/re-run verification.
class CctvVerificationScreen extends StatefulWidget {
  final String claimId;
  final String? claimDescription;

  const CctvVerificationScreen({
    super.key,
    required this.claimId,
    this.claimDescription,
  });

  @override
  State<CctvVerificationScreen> createState() => _CctvVerificationScreenState();
}

class _CctvVerificationScreenState extends State<CctvVerificationScreen> {
  Map<String, dynamic>? _savedResult;
  bool _savedLoading = true;
  String? _savedError;

  bool _verifyLoading = false;
  Map<String, dynamic>? _liveResult;
  String? _verifyError;

  @override
  void initState() {
    super.initState();
    _loadSavedResult();
  }

  Future<void> _loadSavedResult() async {
    setState(() { _savedLoading = true; _savedError = null; });
    try {
      final result = await ApiService.getCctvVerificationResult(widget.claimId);
      if (mounted) setState(() { _savedResult = result; _savedLoading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _savedError = e.toString().contains('404') || e.toString().contains('No verification') 
          ? 'No previous verification found' 
          : e.toString().replaceFirst('Exception: ', '');
        _savedLoading = false;
      });
    }
  }

  Future<void> _runVerification() async {
    setState(() { _verifyLoading = true; _verifyError = null; _liveResult = null; });
    try {
      final result = await ApiService.verifyClaim(widget.claimId);
      if (mounted) {
        setState(() { _liveResult = result; _verifyLoading = false; });
        // Refresh saved result too
        _loadSavedResult();
      }
    } catch (e) {
      if (mounted) setState(() {
        _verifyError = e.toString().replaceFirst('Exception: ', '');
        _verifyLoading = false;
      });
    }
  }

  _VerdictStyle _verdictStyle(String? verdict) {
    switch (verdict) {
      case 'likely_valid':
        return _VerdictStyle(color: Colors.white, icon: LucideIcons.checkCircle, label: 'Likely Valid');
      case 'possibly_valid':
        return _VerdictStyle(color: Colors.white70, icon: LucideIcons.alertTriangle, label: 'Possibly Valid');
      case 'likely_invalid':
        return _VerdictStyle(color: Colors.white30, icon: LucideIcons.xCircle, label: 'Likely Invalid');
      default:
        return _VerdictStyle(color: Colors.white24, icon: LucideIcons.shield, label: verdict ?? 'Unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CCTV Verification'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Claim ID info chip
            GlassBox(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(LucideIcons.video, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Claim ID', style: TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1)),
                        Text(widget.claimId, style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(),
            const SizedBox(height: 16),

            // ─── Run Verification Card ───
            GlassBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(LucideIcons.play, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Run Verification', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
                            Text('CCTV logs + Groq AI verdict', style: TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _verifyLoading ? null : _runVerification,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                        icon: _verifyLoading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(LucideIcons.play, size: 14),
                        label: Text(_verifyLoading ? 'Analyzing...' : 'Verify'),
                      ),
                    ],
                  ),

                  // Analyzing banner
                  if (_verifyLoading) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withAlpha(20))),
                      child: Row(
                        children: [
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Analyzing CCTV logs...', style: TextStyle(fontSize: 13, color: Colors.white)),
                                Text('This may take 10–20 seconds', style: TextStyle(fontSize: 11, color: Colors.white38)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Error
                  if (_verifyError != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withAlpha(20))),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.xCircle, color: Colors.white60, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_verifyError!, style: const TextStyle(color: Colors.white60, fontSize: 12))),
                        ],
                      ),
                    ),
                  ],

                  // Live result
                  if (_liveResult != null) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                    const Text('FRESH RESULT', style: TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    _VerdictCard(result: _liveResult!, verdictStyle: _verdictStyle(_liveResult!['verdict'])),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 16),

            // ─── Saved Result Card ───
            GlassBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(LucideIcons.fileSearch, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Saved Result', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
                            Text('Previously stored AI verification', style: TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _loadSavedResult,
                        icon: const Icon(LucideIcons.refreshCw, size: 16, color: Colors.white38),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_savedLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                  else if (_savedError != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withAlpha(6), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withAlpha(15))),
                      child: Center(child: Text(_savedError!, style: const TextStyle(color: Colors.white38, fontSize: 13))),
                    )
                  else if (_savedResult != null)
                    _VerdictCard(result: _savedResult!, verdictStyle: _verdictStyle(_savedResult!['verdict']))
                  else
                    const Center(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No saved result', style: TextStyle(color: Colors.white38, fontSize: 13)),
                    )),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _VerdictStyle {
  final Color color;
  final IconData icon;
  final String label;
  const _VerdictStyle({required this.color, required this.icon, required this.label});
}

class _VerdictCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final _VerdictStyle verdictStyle;

  const _VerdictCard({required this.result, required this.verdictStyle});

  @override
  Widget build(BuildContext context) {
    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
    final match = result['match'] as bool? ?? false;
    final reasoning = result['reasoning'] as String?;
    final verifiedAt = result['verifiedAt'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Verdict Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: verdictStyle.color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: verdictStyle.color.withAlpha(60)),
          ),
          child: Row(
            children: [
              Icon(verdictStyle.icon, color: verdictStyle.color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(verdictStyle.label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: verdictStyle.color)),
                    const Text('AI Verdict', style: TextStyle(fontSize: 11, color: Colors.white38)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${(confidence * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Text('Confidence', style: TextStyle(fontSize: 10, color: Colors.white38)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Confidence bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: confidence.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.white.withAlpha(12),
            valueColor: AlwaysStoppedAnimation<Color>(verdictStyle.color),
          ),
        ),
        const SizedBox(height: 12),

        // Match flag
        Row(
          children: [
            const Text('Match: ', style: TextStyle(fontSize: 13, color: Colors.white54)),
            Icon(match ? LucideIcons.check : LucideIcons.x, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(match ? 'Yes' : 'No', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),

        // Reasoning
        if (reasoning != null && reasoning.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withAlpha(6), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withAlpha(15))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI REASONING', style: TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(reasoning, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],

        // Verified at
        if (verifiedAt != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 12, color: Colors.white30),
              const SizedBox(width: 4),
              Text('Verified: ${_fmtTimestamp(verifiedAt)}', style: const TextStyle(fontSize: 11, color: Colors.white30)),
            ],
          ),
        ],
      ],
    );
  }

  String _fmtTimestamp(dynamic ts) {
    try {
      if (ts is Map && ts['_seconds'] != null) {
        return DateFormat('dd MMM yyyy, hh:mm a').format(
          DateTime.fromMillisecondsSinceEpoch((ts['_seconds'] as int) * 1000));
      }
      return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(ts.toString()));
    } catch (_) { return ts.toString(); }
  }
}
