import 'package:flutter/material.dart';
import 'package:learning_pwa/models/concept.dart';

class ConceptScreen extends StatelessWidget {
  final Concept concept;

  const ConceptScreen({super.key, required this.concept});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Concept'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              concept.conceptText,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            if (concept.exampleText != null)
              Text(
                'Example: ${concept.exampleText}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
          ],
        ),
      ),
    );
  }
}
