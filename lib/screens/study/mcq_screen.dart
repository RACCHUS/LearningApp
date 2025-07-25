import 'package:flutter/material.dart';
import 'package:learning_pwa/models/question.dart';

class McqScreen extends StatefulWidget {
  final Question question;

  const McqScreen({super.key, required this.question});

  @override
  _McqScreenState createState() => _McqScreenState();
}

class _McqScreenState extends State<McqScreen> {
  int? _selectedOption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiple Choice'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.question.questionText,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            ...widget.question.options.asMap().entries.map((entry) {
              int idx = entry.key;
              String text = entry.value;
              return RadioListTile<int>(
                title: Text(text),
                value: idx,
                groupValue: _selectedOption,
                onChanged: (int? value) {
                  setState(() {
                    _selectedOption = value;
                  });
                },
              );
            }),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _selectedOption == null ? null : () {
                // Handle answer submission
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
