import 'package:flutter/material.dart';

/// Shared page chrome for the demo screens.
class DemoScaffold extends StatelessWidget {
  /// Creates a demo page with a [title], a one-line [blurb] and the demo body.
  const DemoScaffold({
    super.key,
    required this.title,
    required this.blurb,
    required this.child,
  });

  /// Page title.
  final String title;

  /// What to try on this page.
  final String blurb;

  /// The demo itself.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(blurb, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// A small coloured rounded square used as the moving subject in demos.
class DemoBox extends StatelessWidget {
  /// Creates a box of [size] filled with [color].
  const DemoBox(
      {super.key, this.size = 56, this.color = Colors.indigo, this.label});

  /// Edge length.
  final double size;

  /// Fill colour.
  final Color color;

  /// Optional centred label.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: label == null
          ? null
          : Text(label!, style: const TextStyle(color: Colors.white)),
    );
  }
}
