import 'package:flutter/material.dart';

class TagInput extends StatefulWidget {
  final List<String> tags;
  final Function(List<String>) onTagsChanged;
  final List<String>? requiredTags; // Add this new parameter
  final List<String>? suggestedTags; // Add this parameter for tag suggestions

  const TagInput({
    super.key,
    required this.tags,
    required this.onTagsChanged,
    this.requiredTags,
    this.suggestedTags,
  });

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final TextEditingController _controller = TextEditingController();
  late List<String> _suggestions;

  @override
  void initState() {
    super.initState();
    _suggestions =
        widget.suggestedTags ??
        [
          // Basic categories
          'doctor', 'patient', 'appointment', 'medication', 'treatment',

          // Medical specialties
          'cardiology', 'dermatology', 'neurology', 'orthopedics', 'pediatrics',
          'gynecology', 'urology', 'ophthalmology', 'ent', 'psychology',
          'dentistry', 'oncology', 'radiology', 'rheumatology', 'endocrinology',

          // Document types
          'prescription', 'lab-report', 'imaging', 'discharge-summary',
          'surgical-report', 'consultation', 'referral', 'insurance',
          'vaccination', 'consent-form', 'medical-history', 'allergy',

          // Health conditions
          'chronic', 'acute', 'emergency', 'preventive', 'follow-up',
          'diabetes', 'hypertension', 'asthma', 'pregnancy', 'cardiac',
          'allergy',
          'immunization',
          'nutrition',
          'physical-therapy',
          'mental-health',

          // Tests and procedures
          'blood-test', 'x-ray', 'mri', 'ct-scan', 'ultrasound',
          'ecg', 'biopsy', 'surgery', 'vaccination', 'screening',
          'annual-checkup', 'specialist-visit', 'therapy', 'wellness',

          // Payment and administrative
          'billing', 'insurance', 'claim', 'reimbursement', 'pre-authorization',
          'second-opinion', 'confidential', 'urgent', 'routine',
        ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _controller.text.trim().toLowerCase();
    if (tag.isNotEmpty && !widget.tags.contains(tag)) {
      final List<String> updatedTags = [...widget.tags, tag];
      widget.onTagsChanged(updatedTags);
      _controller.clear();
    }
  }

  void _removeTag(String tag) {
    // Don't allow removal of required tags
    if (widget.requiredTags != null && widget.requiredTags!.contains(tag)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('The tag "$tag" is required and cannot be removed'),
        ),
      );
      return;
    }

    final List<String> updatedTags =
        widget.tags.where((t) => t != tag).toList();
    widget.onTagsChanged(updatedTags);
  }

  void _addSuggestedTag(String tag) {
    if (!widget.tags.contains(tag)) {
      final List<String> updatedTags = [...widget.tags, tag];
      widget.onTagsChanged(updatedTags);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Add tag...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.add), onPressed: _addTag),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children:
              widget.tags.map((tag) {
                final bool isRequired =
                    widget.requiredTags != null &&
                    widget.requiredTags!.contains(tag);
                return Chip(
                  label: Text(tag),
                  deleteIcon:
                      isRequired ? null : const Icon(Icons.close, size: 18),
                  onDeleted: isRequired ? null : () => _removeTag(tag),
                  backgroundColor: isRequired ? Colors.blue.shade100 : null,
                );
              }).toList(),
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Suggested tags:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children:
                _suggestions
                    .where((tag) => !widget.tags.contains(tag))
                    .map(
                      (tag) => ActionChip(
                        label: Text(tag),
                        onPressed: () => _addSuggestedTag(tag),
                      ),
                    )
                    .toList(),
          ),
        ],
      ],
    );
  }
}
