import 'package:flutter/material.dart';
import 'package:happ/core/services/medical_nlp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicalTermSimplifier extends StatefulWidget {
  final String medicalText;
  final TextStyle? textStyle;
  final TextStyle? simplifiedStyle;
  final bool initiallySimplified;

  const MedicalTermSimplifier({
    super.key,
    required this.medicalText,
    this.textStyle,
    this.simplifiedStyle,
    this.initiallySimplified = true,
  });

  @override
  State<MedicalTermSimplifier> createState() => _MedicalTermSimplifierState();
}

class _MedicalTermSimplifierState extends State<MedicalTermSimplifier> {
  final MedicalNlpService _nlpService = MedicalNlpService();
  bool _isSimplified = true;
  bool _isLoading = true;
  List<SimplifiedMedicalTerm> _simplifiedTerms = [];
  
  @override
  void initState() {
    super.initState();
    _isSimplified = widget.initiallySimplified;
    _loadSimplificationPreference();
    _processText();
  }

  @override
  void didUpdateWidget(MedicalTermSimplifier oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.medicalText != widget.medicalText) {
      _processText();
    }
  }

  Future<void> _loadSimplificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSimplified = prefs.getBool('simplify_medical_terms') ?? widget.initiallySimplified;
    });
  }

  Future<void> _saveSimplificationPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('simplify_medical_terms', value);
  }

  Future<void> _processText() async {
    setState(() {
      _isLoading = true;
    });

    final simplifiedTerms = await _nlpService.simplifyMedicalText(widget.medicalText);
    
    if (mounted) {
      setState(() {
        _simplifiedTerms = simplifiedTerms;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_simplifiedTerms.isEmpty || !_isSimplified) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.medicalText,
            style: widget.textStyle,
          ),
          if (_simplifiedTerms.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.medical_services),
                label: const Text('Simplify Medical Terms'),
                onPressed: () {
                  setState(() {
                    _isSimplified = true;
                  });
                  _saveSimplificationPreference(true);
                },
              ),
            ),
        ],
      );
    }

    // Build rich text with highlighted medical terms
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRichText(),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.medical_services, color: Colors.blue),
            label: const Text('Show Original Text'),
            onPressed: () {
              setState(() {
                _isSimplified = false;
              });
              _saveSimplificationPreference(false);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRichText() {
    final List<InlineSpan> spans = [];
    int lastEnd = 0;

    for (final term in _simplifiedTerms) {
      // Add text before the term
      if (term.startIndex > lastEnd) {
        spans.add(
          TextSpan(
            text: widget.medicalText.substring(lastEnd, term.startIndex),
            style: widget.textStyle,
          ),
        );
      }

      // Add the simplified term
      spans.add(
        WidgetSpan(
          child: GestureDetector(
            onTap: () => _showDefinitionDialog(term),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: RichText(
                text: TextSpan(
                  text: term.original,
                  style: widget.textStyle?.copyWith(
                    color: Colors.black,
                  ) ?? const TextStyle(color: Colors.black),
                  children: [
                    TextSpan(
                      text: ' (${term.simplified})',
                      style: widget.simplifiedStyle?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ) ?? const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      lastEnd = term.endIndex;
    }

    // Add any remaining text
    if (lastEnd < widget.medicalText.length) {
      spans.add(
        TextSpan(
          text: widget.medicalText.substring(lastEnd),
          style: widget.textStyle,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }

  void _showDefinitionDialog(SimplifiedMedicalTerm term) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          term.original,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simple Term:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              term.simplified,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Definition:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              term.definition,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}