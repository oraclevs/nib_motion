import 'package:flutter/painting.dart';

import 'motion_value.dart';

/// A [MotionValue] holding an animatable background color, or `null` for
/// "no color".
typedef ColorMotionValue = MotionValue<Color?>;

/// A [MotionValue] holding an animatable list of [BoxShadow]s, or `null` for
/// "no shadow".
typedef BoxShadowMotionValue = MotionValue<List<BoxShadow>?>;
