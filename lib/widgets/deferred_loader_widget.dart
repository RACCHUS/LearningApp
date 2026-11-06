import 'package:flutter/material.dart';

typedef LibraryLoader = Future<void> Function();
typedef DeferredWidgetBuilder = Widget Function();

/// A widget that asynchronously loads a deferred Dart library before rendering.
///
/// This reduces initial Web bundle sizes by splitting rarely visited screens
/// (e.g. Governance, Taxonomy Explorer, Course Builder, Guided Generation) into
/// separate deferred chunk payloads (.part.js) loaded on demand.
class DeferredLoaderWidget extends StatefulWidget {
  final LibraryLoader loader;
  final DeferredWidgetBuilder builder;
  final Widget? fallback;

  const DeferredLoaderWidget({
    super.key,
    required this.loader,
    required this.builder,
    this.fallback,
  });

  @override
  State<DeferredLoaderWidget> createState() => _DeferredLoaderWidgetState();
}

class _DeferredLoaderWidgetState extends State<DeferredLoaderWidget> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.builder();
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error Loading Component')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load component: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadFuture = widget.loader();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return widget.fallback ??
            const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
      },
    );
  }
}

