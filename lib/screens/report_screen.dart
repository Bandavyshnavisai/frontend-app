import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../widgets/glass_box.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'lost';
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  XFile? _imageFile;
  bool _isSubmitting = false;
  bool _aiProcessing = false;
  String _aiStatusMessage = '';

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final itemData = {
        'title': _titleController.text.trim(),
        'type': _type,
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      final newItem = await ApiService.createItem(itemData);

      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        await ApiService.uploadItemImage(newItem.id, base64Image);

        // AI Processing Pipeline
        setState(() { _aiProcessing = true; _aiStatusMessage = 'Extracting visual features...'; });
        final collection = _type == 'lost' ? 'lostItems' : 'foundItems';
        try {
          await ApiService.extractFeatures(newItem.id, collection);
          setState(() => _aiStatusMessage = 'Comparing against database items...');
          await ApiService.compareAndSuggest(newItem.id, collection);
        } catch (aiErr) {
          // AI is optional, swallow error
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item reported successfully!')));
        context.go('/');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to report item: $e')));
    } finally {
      if (mounted) setState(() { _isSubmitting = false; _aiProcessing = false; _aiStatusMessage = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Step 1: Item Type
              GlassBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StepHeader(number: '1', label: 'Item Type', color: Colors.white),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _type = 'lost'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: _type == 'lost' ? Colors.white.withOpacity(0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _type == 'lost' ? Colors.white.withOpacity(0.5) : Colors.white10),
                              ),
                              child: const Column(
                                children: [
                                  Text('🔴', style: TextStyle(fontSize: 20)),
                                  SizedBox(height: 4),
                                  Text('Lost Item', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _type = 'found'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: _type == 'found' ? Colors.white.withOpacity(0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _type == 'found' ? Colors.white.withOpacity(0.5) : Colors.white10),
                              ),
                              child: const Column(
                                children: [
                                  Text('🟢', style: TextStyle(fontSize: 20)),
                                  SizedBox(height: 4),
                                  Text('Found Item', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
              const SizedBox(height: 16),

              // Step 2: Item Details
              GlassBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StepHeader(number: '2', label: 'Item Details', color: Colors.white70),
                    const SizedBox(height: 16),
                    _FieldLabel(icon: LucideIcons.tag, label: 'Title'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(hintText: 'e.g. Blue Backpack'),
                      validator: (v) => v == null || v.isEmpty ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(icon: LucideIcons.mapPin, label: 'Location'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(hintText: 'e.g. Library 2nd Floor'),
                      validator: (v) => v == null || v.isEmpty ? 'Please enter a location' : null,
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(icon: LucideIcons.fileText, label: 'Description'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(hintText: 'Provide a detailed description...'),
                      validator: (v) => v == null || v.isEmpty ? 'Please enter a description' : null,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
              const SizedBox(height: 16),

              // Step 3: Photo
              GlassBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _StepHeader(number: '3', label: 'Photo', color: Colors.white38),
                      const Spacer(),
                      const Text('Optional', style: TextStyle(fontSize: 11, color: Colors.white30)),
                    ]),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _pickImage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: _imageFile != null ? null : 130,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white.withOpacity(0.03),
                          border: Border.all(
                            color: _imageFile != null ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.08),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: _imageFile != null
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset(_imageFile!.path, errorBuilder: (_, __, ___) => const Icon(LucideIcons.image, color: Colors.greenAccent, size: 40))),
                                  const SizedBox(height: 8),
                                  Text('Selected: ${_imageFile!.name}', style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
                                  TextButton(onPressed: () => setState(() => _imageFile = null), child: const Text('Remove', style: TextStyle(color: Colors.white38, fontSize: 12))),
                                ],
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.image, color: Colors.white38, size: 32),
                                SizedBox(height: 8),
                                Text('Tap to add photo', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w500)),
                                SizedBox(height: 4),
                                Text('PNG, JPG up to 10MB', style: TextStyle(color: Colors.white30, fontSize: 11)),
                              ],
                            ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
              const SizedBox(height: 16),

              // AI Status
              if (_aiProcessing)
                GlassBox(
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 20),
                      ).animate(onPlay: (c) => c.repeat()).shimmer(),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_aiStatusMessage, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 13)),
                          const Text('AI is processing your item image', style: TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn().scale(),

              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => context.go('/'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isSubmitting || _aiProcessing) ? null : _submit,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: (_isSubmitting || _aiProcessing)
                        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            const SizedBox(width: 8),
                            Flexible(child: Text(_aiProcessing ? _aiStatusMessage : 'Submitting...', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ])
                        : const Text('Submit Report'),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class _StepHeader extends StatelessWidget {
  final String number;
  final String label;
  final Color color;
  const _StepHeader({required this.number, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(number, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold))),
      ),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FieldLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 13, color: Colors.white38),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white54)),
    ],
  );
}
