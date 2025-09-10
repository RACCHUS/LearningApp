import 'package:flutter/material.dart';
import '../services/content_quality_service.dart';

class ContentQualityWidget extends StatefulWidget {
  final Map<String, dynamic> lessonData;
  final Function(List<ContentSuggestion>) onSuggestionsApplied;

  const ContentQualityWidget({
    Key? key,
    required this.lessonData,
    required this.onSuggestionsApplied,
  }) : super(key: key);

  @override
  State<ContentQualityWidget> createState() => _ContentQualityWidgetState();
}

class _ContentQualityWidgetState extends State<ContentQualityWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  ContentQualityReport? _qualityReport;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _analyzeContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _analyzeContent() {
    setState(() => _isAnalyzing = true);
    
    // Simulate analysis delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _qualityReport = ContentQualityService.analyzeLesson(widget.lessonData);
          _isAnalyzing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing content quality...'),
          ],
        ),
      );
    }

    if (_qualityReport == null) {
      return const Center(child: Text('Failed to analyze content'));
    }

    return Column(
      children: [
        // Header with overall score
        _buildOverallScoreHeader(),
        
        const SizedBox(height: 16),
        
        // Tab navigation
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Overview'),
            Tab(icon: Icon(Icons.book), text: 'Readability'),
            Tab(icon: Icon(Icons.accessibility), text: 'Accessibility'),
            Tab(icon: Icon(Icons.architecture), text: 'Structure'),
            Tab(icon: Icon(Icons.lightbulb), text: 'Suggestions'),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildReadabilityTab(),
              _buildAccessibilityTab(),
              _buildStructureTab(),
              _buildSuggestionsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverallScoreHeader() {
    final score = _qualityReport!.overallScore;
    Color scoreColor;
    String scoreLabel;
    
    if (score >= 80) {
      scoreColor = Colors.green;
      scoreLabel = 'Excellent';
    } else if (score >= 60) {
      scoreColor = Colors.orange;
      scoreLabel = 'Good';
    } else {
      scoreColor = Colors.red;
      scoreLabel = 'Needs Improvement';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Score circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scoreColor.withOpacity(0.1),
                border: Border.all(color: scoreColor, width: 3),
              ),
              child: Center(
                child: Text(
                  '${score.round()}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 20),
            
            // Score details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Content Quality Score',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scoreLabel,
                    style: TextStyle(
                      fontSize: 18,
                      color: scoreColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Based on content structure, readability, accessibility, and terminology consistency.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            
            // Quick stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildQuickStat('Issues', '${_qualityReport!.accessibilityChecks.issues.length}'),
                _buildQuickStat('Suggestions', '${_qualityReport!.suggestions.length}'),
                _buildQuickStat('Reading Time', '${_qualityReport!.detailedMetrics['estimatedReadingTime']}m'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final metrics = _qualityReport!.detailedMetrics;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content metrics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Content Metrics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricRow('Word Count', '${metrics['wordCount']}'),
                  _buildMetricRow('Sentences', '${metrics['sentenceCount']}'),
                  _buildMetricRow('Reading Time', '${metrics['estimatedReadingTime']} minutes'),
                  _buildMetricRow('Technical Terms', '${(metrics['technicalTerms'] as List).length}'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Component scores
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Component Scores',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildScoreBar('Structure', _qualityReport!.contentStructure.structureScore),
                  _buildScoreBar('Terminology', _qualityReport!.terminologyConsistency.consistencyScore),
                  _buildScoreBar('Accessibility', _qualityReport!.accessibilityChecks.overallRating),
                  _buildScoreBar('Readability', 100 - (_qualityReport!.readabilityAnalysis.fleschKincaidGrade * 5).clamp(0, 100)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBar(String label, double score) {
    Color color;
    if (score >= 80) {
      color = Colors.green;
    } else if (score >= 60) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                '${score.round()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildReadabilityTab() {
    final readability = _qualityReport!.readabilityAnalysis;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Readability Analysis',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildReadabilityMetric('Reading Level', readability.readabilityLevel),
                  _buildReadabilityMetric('Grade Level', '${readability.fleschKincaidGrade.toStringAsFixed(1)}'),
                  _buildReadabilityMetric('Avg. Sentence Length', '${readability.averageSentenceLength.toStringAsFixed(1)} words'),
                  _buildReadabilityMetric('Avg. Word Length', '${readability.averageWordLength.toStringAsFixed(1)} chars'),
                  _buildReadabilityMetric('Complex Words', '${readability.complexWordPercentage.toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ),
          
          if (readability.suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Readability Suggestions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...readability.suggestions.map((suggestion) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(suggestion)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadabilityMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityTab() {
    final accessibility = _qualityReport!.accessibilityChecks;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accessibility overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Accessibility Rating',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getComplianceColor(accessibility.complianceLevel).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _getComplianceColor(accessibility.complianceLevel)),
                        ),
                        child: Text(
                          accessibility.complianceLevel,
                          style: TextStyle(
                            color: _getComplianceColor(accessibility.complianceLevel),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildScoreBar('Overall Rating', accessibility.overallRating),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Issues
          if (accessibility.issues.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accessibility Issues (${accessibility.issues.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...accessibility.issues.map((issue) => _buildIssueItem(issue)),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Text(
                      'No accessibility issues found!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Recommendations
          if (accessibility.recommendations.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommendations',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...accessibility.recommendations.map((rec) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.recommend, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(child: Text(rec)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getComplianceColor(String level) {
    switch (level) {
      case 'AAA':
        return Colors.green;
      case 'AA':
        return Colors.lightGreen;
      case 'A':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  Widget _buildIssueItem(AccessibilityIssue issue) {
    Color severityColor;
    IconData severityIcon;
    
    switch (issue.severity) {
      case AccessibilitySeverity.high:
        severityColor = Colors.red;
        severityIcon = Icons.error;
        break;
      case AccessibilitySeverity.medium:
        severityColor = Colors.orange;
        severityIcon = Icons.warning;
        break;
      case AccessibilitySeverity.low:
        severityColor = Colors.blue;
        severityIcon = Icons.info;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: severityColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
          color: severityColor.withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(severityIcon, color: severityColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    issue.description,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Location: ${issue.location}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Suggestion: ${issue.suggestion}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStructureTab() {
    final structure = _qualityReport!.contentStructure;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Structure overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Content Structure Analysis',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricRow('Total Items', '${structure.totalItems}'),
                  _buildMetricRow('Content Types', '${structure.typeDistribution.length}'),
                  _buildMetricRow('Balanced Structure', structure.hasBalancedStructure ? 'Yes' : 'No'),
                  const SizedBox(height: 12),
                  _buildScoreBar('Structure Score', structure.structureScore),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Type distribution
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Content Type Distribution',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...structure.typeDistribution.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getTypeColor(entry.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_capitalizeType(entry.key)),
                        const Spacer(),
                        Text(
                          '${entry.value} items',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Missing types and recommendations
          if (structure.missingTypes.isNotEmpty || structure.recommendations.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Structure Recommendations',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (structure.missingTypes.isNotEmpty) ...[
                      Text(
                        'Missing Content Types:',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      ...structure.missingTypes.map((type) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.add_circle_outline, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(_capitalizeType(type)),
                          ],
                        ),
                      )),
                      const SizedBox(height: 12),
                    ],
                    ...structure.recommendations.map((rec) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(child: Text(rec)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'term':
        return Colors.blue;
      case 'concept':
        return Colors.green;
      case 'mcq':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _capitalizeType(String type) {
    switch (type) {
      case 'mcq':
        return 'Multiple Choice Questions';
      case 'term':
        return 'Terms';
      case 'concept':
        return 'Concepts';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  Widget _buildSuggestionsTab() {
    final suggestions = _qualityReport!.suggestions;
    
    if (suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Great job!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            const Text('No suggestions for improvement at this time.'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${suggestions.length} Suggestions for Improvement',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...suggestions.map((suggestion) => _buildSuggestionCard(suggestion)),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(ContentSuggestion suggestion) {
    Color priorityColor;
    IconData priorityIcon;
    
    switch (suggestion.priority) {
      case SuggestionPriority.high:
        priorityColor = Colors.red;
        priorityIcon = Icons.priority_high;
        break;
      case SuggestionPriority.medium:
        priorityColor = Colors.orange;
        priorityIcon = Icons.warning;
        break;
      case SuggestionPriority.low:
        priorityColor = Colors.blue;
        priorityIcon = Icons.info;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(priorityIcon, color: priorityColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: priorityColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    suggestion.priority.name.toUpperCase(),
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(suggestion.description),
            const SizedBox(height: 8),
            Text(
              'Impact: ${suggestion.estimatedImpact}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
