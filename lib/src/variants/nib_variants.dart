import '../core/nib_anim.dart';

/// A named set of [NibAnim] states that `NibMotion.initial`/`NibMotion.animate`
/// can reference by name (instead of a literal [NibAnim]), and that
/// descendant `NibMotion`s with their own `variants` can react to via
/// propagation.
///
/// ```dart
/// const containerVariants = {
///   'hidden': NibAnim(opacity: 0),
///   'visible': NibAnim(opacity: 1),
/// };
/// ```
typedef NibVariants = Map<String, NibAnim>;
