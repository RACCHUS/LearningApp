import 'package:flutter/material.dart';

/// Documentation and help screen for lesson creation
class LessonCreationGuideScreen extends StatelessWidget {
  const LessonCreationGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Creation Guide'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              'Getting Started',
              Icons.play_arrow,
              [
                'Choose your preferred creation method:',
                '• AI Assistant - Generate content with AI prompts',
                '• JSON Import - Import from existing JSON files',
                '• Manual Builder - Build step-by-step with forms',
              ],
            ),
            
            _buildSection(
              context,
              'AI-Assisted Creation',
              Icons.auto_awesome,
              [
                '1. Be specific with your subject - avoid broad topics',
                '2. Choose appropriate difficulty and audience',
                '3. Generate and copy the AI prompt',
                '4. Use the prompt with ChatGPT, Claude, or similar',
                '5. Import the generated JSON response',
                '',
                'Good subjects: "Python Variable Types", "HTTP Status Codes"',
                'Too broad: "Programming", "Computer Science"',
              ],
            ),
            
            _buildSection(
              context,
              'Content Types',
              Icons.category,
              [
                'Terms: Key definitions with examples',
                '• Title: The term or concept name',
                '• Content: Clear, concise definition',
                '• Example: Practical usage example',
                '',
                'Concepts: Detailed explanations',
                '• Title: Main concept name',
                '• Content: Comprehensive explanation',
                '• Key Points: Bullet list of important aspects',
                '',
                'MCQs: Multiple choice questions',
                '• Question: Clear, specific question',
                '• Options: 4 choices (exactly)',
                '• Correct Answer: Must match one option exactly',
                '• Explanation: Why the answer is correct',
              ],
            ),
            
            _buildSection(
              context,
              'Best Practices',
              Icons.star,
              [
                'Content Balance:',
                '• Terms: 30% - Key vocabulary and definitions',
                '• Concepts: 40% - Explanations and understanding',
                '• MCQs: 30% - Assessment and reinforcement',
                '',
                'Quality Guidelines:',
                '• Keep definitions clear and concise',
                '• Use practical, relevant examples',
                '• Write questions that test understanding',
                '• Ensure logical progression from basic to advanced',
                '',
                'Lesson Structure:',
                '• Start with fundamental terms',
                '• Build concepts on established vocabulary',
                '• End with assessment questions',
                '• Include cross-references where appropriate',
              ],
            ),
            
            _buildSection(
              context,
              'JSON Structure Reference',
              Icons.code,
              [
                'Lesson metadata:',
                '• title: 5-100 characters, descriptive',
                '• description: 50-500 characters, learning goals',
                '• estimated_duration_minutes: 15-120 minutes',
                '• difficulty_level: beginner/intermediate/advanced',
                '• tags: Optional categorization array',
                '',
                'Content requirements:',
                '• Each content item needs a "type" field',
                '• All fields are case-sensitive',
                '• Arrays must use proper JSON syntax',
                '• Quotes must be properly escaped',
              ],
            ),
            
            _buildSection(
              context,
              'Common Issues & Solutions',
              Icons.troubleshoot,
              [
                'JSON Import Errors:',
                '• Check for missing quotes around strings',
                '• Ensure all brackets and braces are balanced',
                '• Verify comma placement (no trailing commas)',
                '• Check that correct_answer matches an option exactly',
                '',
                'Content Quality Issues:',
                '• Definitions too long → Break into key points',
                '• Examples unclear → Use concrete, specific cases',
                '• Questions too easy → Test application, not recall',
                '• Poor progression → Start basic, build complexity',
                '',
                'AI Prompt Issues:',
                '• Subject too broad → Make more specific',
                '• Generated content poor → Adjust parameters and retry',
                '• JSON invalid → Use validation prompt template',
              ],
            ),
            
            const SizedBox(height: 32),
            
            Card(
              color: Colors.blue.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Pro Tips',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Start with AI Assistant for quick content generation\n'
                      '• Use Manual Builder for precise control\n'
                      '• Save successful prompts for similar lessons\n'
                      '• Test your lessons before sharing\n'
                      '• Use tags for easy organization and filtering\n'
                      '• Consider your audience\'s prior knowledge',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<String> content,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...content.map((line) => line.isEmpty 
                ? const SizedBox(height: 8)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: line.startsWith('•') || line.endsWith(':')
                          ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: line.endsWith(':') 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                            )
                          : Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
