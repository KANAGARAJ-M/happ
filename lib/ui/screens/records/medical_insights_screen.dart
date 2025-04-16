import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:happ/core/models/record.dart';
import 'package:happ/core/services/blockchain_service.dart';
import 'package:happ/core/services/medical_nlp_service.dart';

class MedicalInsightsScreen extends StatefulWidget {
  final Record record;
  
  const MedicalInsightsScreen({super.key, required this.record});

  @override
  State<MedicalInsightsScreen> createState() => _MedicalInsightsScreenState();
}

class _MedicalInsightsScreenState extends State<MedicalInsightsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, DocumentAnalysisResult>? _analysisResults;
  String? _errorMessage;
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _progressAnimation;
  
  // Text animation variables
  final List<String> _analyzingMessages = [
    'Scanning medical terminology...',
    'Identifying conditions...',
    'Cross-referencing medical database...',
    'Processing health indicators...',
    'Analyzing potential interactions...',
    'Generating insights...',
  ];
  int _currentMessageIndex = 0;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    
    // Pulse animation for the progress indicator
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    // Scanning animation
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    // Progress animation
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );
    
    // Cycle through analyzing messages
    Future.delayed(const Duration(seconds: 1), () {
      _cycleAnalyzingMessages();
    });
    
    // Start analysis
    _analyzeRecord();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _cycleAnalyzingMessages() {
    if (!mounted || !_isLoading) return;
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _isLoading) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _analyzingMessages.length;
        });
        _cycleAnalyzingMessages();
      }
    });
  }
  
  Future<void> _analyzeRecord() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Simulate AI processing time - 5 seconds
      await Future.delayed(const Duration(seconds: 5));
      
      final results = await BlockchainService().analyzeRecordContent(widget.record);
      
      if (mounted) {
        setState(() {
          _analysisResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error analyzing record: $e';
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Insights AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh analysis',
            onPressed: _isLoading ? null : _analyzeRecord,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingAnimation()
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _buildResults(),
    );
  }
  
  Widget _buildLoadingAnimation() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Brain icon with pulse effect
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology,
                    size: 60,
                    color: Colors.blue,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Document scan effect
              Container(
                width: 280,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    // Document background
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(6, (index) => 
                          Container(
                            height: 10,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            width: 260 - (index * 20 % 130),
                            color: Colors.grey.shade200,
                          )
                        ),
                      ),
                    ),
                    
                    // Scanning animation
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _scanAnimation.value * 180 - 30,
                      child: Container(
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.blue.withOpacity(0.8),
                              Colors.blue.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Scan line
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _scanAnimation.value * 180,
                      child: Container(
                        height: 2,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // AI analyzing text
              Text(
                'Our AI is analyzing your medical record',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              Text(
                _analyzingMessages[_currentMessageIndex],
                style: TextStyle(color: Colors.blue.shade700, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Neural network connection animation
              SizedBox(
                width: 280,
                height: 40,
                child: CustomPaint(
                  painter: NeuralNetworkPainter(
                    animationValue: _animationController.value,
                    dotColor: Colors.blue,
                    lineColor: Colors.blue.withOpacity(0.5),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Progress indicator
              Container(
                width: 280,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 280 * (_progressAnimation.value * 0.9 + 0.1 * math.sin(_animationController.value * 10)),
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade300, Colors.blue],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Rest of the existing code...
  Widget _buildResults() {
    // Collect all insights from all documents
    final List<MedicalInsight> allInsights = [];
    _analysisResults?.forEach((fileUrl, result) {
      allInsights.addAll(result.criticalInsights);
    });
    
    // If no insights found
    if (allInsights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'No medical concerns detected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This record does not contain any recognized medical conditions',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // Sort insights by severity (High, Medium, Low)
    allInsights.sort((a, b) {
      final Map<String, int> severityOrder = {'High': 0, 'Medium': 1, 'Low': 2};
      final aOrder = severityOrder[a.severity ?? 'Low'] ?? 3;
      final bOrder = severityOrder[b.severity ?? 'Low'] ?? 3;
      return aOrder.compareTo(bOrder);
    });
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add reveal animation for results
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 800),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analysis Summary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We found ${allInsights.length} potential medical conditions in this record.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 14,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Important: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(
                            text: 'This analysis is for informational purposes only. '
                                 'Always consult with a healthcare professional for medical advice.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Insights list section
          Text(
            'Detected Medical Conditions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          // Animated list of insights
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allInsights.length,
            itemBuilder: (context, index) {
              final insight = allInsights[index];
              
              // Staggered animation for each card
              return TweenAnimationBuilder(
                duration: Duration(milliseconds: 500 + (index * 100)),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 50 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: _buildInsightCard(context, insight),
              );
            },
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildInsightCard(BuildContext context, MedicalInsight insight) {
    Color severityColor = Colors.grey;
    
    switch (insight.severity) {
      case 'High':
        severityColor = Colors.red;
        break;
      case 'Medium':
        severityColor = Colors.orange;
        break;
      case 'Low':
        severityColor = Colors.green;
        break;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    insight.severity ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Confidence: ${insight.confidenceScore}%',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              insight.term,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(insight.definition),
            if (insight.recommendation != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Recommendation:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(insight.recommendation!),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.info_outline),
                label: const Text('Learn More'),
                onPressed: () {
                  // In a real app, this would open detailed information about the condition
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Information about ${insight.term}')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for neural network animation
class NeuralNetworkPainter extends CustomPainter {
  final double animationValue;
  final Color dotColor;
  final Color lineColor;
  
  NeuralNetworkPainter({
    required this.animationValue,
    required this.dotColor,
    required this.lineColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    // Create a network of dots (neurons)
    final dots = <Offset>[];
    
    // First column of dots (input layer)
    for (int i = 0; i < 3; i++) {
      dots.add(Offset(20, 10 + i * 15));
    }
    
    // Hidden layer
    for (int i = 0; i < 5; i++) {
      dots.add(Offset(size.width / 2, 5 + i * 10));
    }
    
    // Output layer
    for (int i = 0; i < 2; i++) {
      dots.add(Offset(size.width - 20, 15 + i * 15));
    }
    
    // Draw connections with animated highlights
    for (int i = 0; i < 3; i++) {
      for (int j = 3; j < 8; j++) {
        // Draw connection lines
        final path = Path();
        path.moveTo(dots[i].dx, dots[i].dy);
        path.lineTo(dots[j].dx, dots[j].dy);
        
        // Check if this connection should be highlighted
        final highlight = (i + j) % 3 == (animationValue * 3).floor() % 3;
        
        // Draw the connection
        canvas.drawPath(
          path,
          Paint()
            ..color = highlight ? dotColor : lineColor
            ..strokeWidth = highlight ? 2.5 : 1.0
            ..style = PaintingStyle.stroke
        );
      }
    }
    
    // Connect hidden layer to output layer
    for (int i = 3; i < 8; i++) {
      for (int j = 8; j < 10; j++) {
        final path = Path();
        path.moveTo(dots[i].dx, dots[i].dy);
        path.lineTo(dots[j].dx, dots[j].dy);
        
        // Check if this connection should be highlighted
        final highlight = (i + j) % 5 == (animationValue * 5).floor() % 5;
        
        // Draw the connection
        canvas.drawPath(
          path,
          Paint()
            ..color = highlight ? dotColor : lineColor
            ..strokeWidth = highlight ? 2.5 : 1.0
            ..style = PaintingStyle.stroke
        );
      }
    }
    
    // Draw pulsing dots
    for (final dot in dots) {
      final pulseOffset = math.sin((animationValue * 2 * math.pi) + dots.indexOf(dot) * 0.5);
      final radius = 3.0 + pulseOffset;
      canvas.drawCircle(dot, radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(NeuralNetworkPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}