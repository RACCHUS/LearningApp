import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget for displaying and managing AI prompts
class PromptDisplayWidget extends StatelessWidget {
  final String title;
  final String prompt;
  final String? instructions;
  final VoidCallback? onCopy;

  const PromptDisplayWidget({
    super.key,
    required this.title,
    required this.prompt,
    this.instructions,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyPrompt(context),
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy to clipboard',
                ),
              ],
            ),
            
            if (instructions != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        instructions!,
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            Container(
              width: double.infinity,
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  prompt,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyPrompt(context),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Prompt'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showFullPrompt(context),
                    icon: const Icon(Icons.fullscreen, size: 16),
                    label: const Text('View Full'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _copyPrompt(BuildContext context) {
    Clipboard.setData(ClipboardData(text: prompt));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Prompt copied to clipboard!'),
          ],
        ),
      ),
    );
    onCopy?.call();
  }

  void _showFullPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          child: SingleChildScrollView(
            child: SelectableText(
              prompt,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copyPrompt(context),
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Quick access widget for common prompt templates
class PromptTemplatesWidget extends StatelessWidget {
  const PromptTemplatesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_snippet, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Quick Templates',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildTemplateButton(
              context,
              'Content Quality Check',
              'Analyze and improve existing lesson content',
              Icons.check_circle_outline,
              () => _copyTemplate(context, 'quality'),
            ),
            
            const SizedBox(height: 8),
            
            _buildTemplateButton(
              context,
              'Break Down Broad Topic',
              'Split complex subjects into focused lessons',
              Icons.call_split,
              () => _copyTemplate(context, 'split'),
            ),
            
            const SizedBox(height: 8),
            
            _buildTemplateButton(
              context,
              'Validate JSON Structure',
              'Check and fix lesson JSON formatting',
              Icons.code,
              () => _copyTemplate(context, 'validate'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateButton(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.copy, size: 16),
          ],
        ),
      ),
    );
  }

  void _copyTemplate(BuildContext context, String type) {
    String prompt;
    String templateName;
    
    switch (type) {
      case 'quality':
        prompt = '''
You are an educational content quality expert. Please analyze the following lesson content and provide specific improvement suggestions:

CONTENT TO ANALYZE:
[PASTE YOUR LESSON CONTENT HERE]

Please provide feedback on:
1. CONTENT QUALITY (clarity, effectiveness, examples)
2. STRUCTURE & FLOW (logical progression, balance)
3. ASSESSMENT QUALITY (MCQ effectiveness, explanations)
4. SPECIFIC RECOMMENDATIONS (actionable improvements)
5. ENGAGEMENT FACTORS (ways to enhance learning)

Provide specific, actionable suggestions for improvement.
''';
        templateName = 'Content Quality Check';
        break;
        
      case 'split':
        prompt = '''
You are an educational curriculum designer. The topic "[ENTER BROAD TOPIC HERE]" is too broad for a single lesson. Please create a structured lesson series.

Create 3-7 focused lessons with:
- Clear prerequisites and learning progression
- 15-60 minutes duration each
- Logical flow from foundational to advanced
- Specific learning objectives for each lesson

Provide a comprehensive lesson series breakdown with cross-references between lessons.
''';
        templateName = 'Topic Splitting';
        break;
        
      case 'validate':
        prompt = '''
You are a JSON schema validator and educational content reviewer. Please validate the following lesson JSON:

LESSON JSON TO VALIDATE:
[PASTE YOUR JSON HERE]

Check for:
1. JSON STRUCTURE (syntax, required fields, data types)
2. CONTENT REQUIREMENTS (appropriate lengths, formats)
3. CONTENT QUALITY (clear definitions, good examples)
4. EDUCATIONAL STANDARDS (age-appropriate, clear objectives)

Provide ✅ VALID, ❌ ERRORS, ⚠️ WARNINGS, and 💡 RECOMMENDATIONS.
''';
        templateName = 'JSON Validation';
        break;
        
      default:
        prompt = 'Unknown template type';
        templateName = 'Unknown';
    }

    Clipboard.setData(ClipboardData(text: prompt));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$templateName template copied to clipboard!'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _showTemplateDialog(context, templateName, prompt),
        ),
      ),
    );
  }

  void _showTemplateDialog(BuildContext context, String title, String prompt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              prompt,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: prompt));
              Navigator.of(context).pop();
            },
            child: const Text('Copy Again'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
