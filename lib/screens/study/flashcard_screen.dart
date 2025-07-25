import 'package:flutter/material.dart';
import 'package:learning_pwa/models/term.dart';

class FlashcardScreen extends StatefulWidget {
  final Term term;

  const FlashcardScreen({super.key, required this.term});

  @override
  _FlashcardScreenState createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  bool _isFlipped = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcard'),
      ),
      body: Center(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isFlipped = !_isFlipped;
            });
          },
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                _isFlipped ? widget.term.definition : widget.term.term,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
