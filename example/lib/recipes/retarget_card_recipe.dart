import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

/// A self-contained spring retarget example. Tap again before it settles to
/// reverse from the card's current position and velocity.
class RetargetCardRecipe extends StatefulWidget {
  const RetargetCardRecipe({super.key, this.distance = 120})
      : assert(distance >= 0 && distance <= 240);

  /// Horizontal travel in logical pixels. Keep this within the host track.
  final double distance;

  @override
  State<RetargetCardRecipe> createState() => _RetargetCardRecipeState();
}

class _RetargetCardRecipeState extends State<RetargetCardRecipe> {
  bool _moved = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          onPressed: () => setState(() => _moved = !_moved),
          child: Text(_moved ? 'Reset card' : 'Move card'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 64,
          child: Align(
            alignment: Alignment.centerLeft,
            child: NibMotion(
              animate: NibAnim(x: _moved ? widget.distance : 0),
              transition: NibTransition.springSnappy,
              child: Semantics(
                key: const ValueKey('retarget-card'),
                label: 'Animated card',
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
