/// The scalar properties of a `NibMotion` whose live [MotionValue] (and
/// therefore value and velocity) can be read through
/// `NibMotionController.motionValueOf` / `velocityOf`.
///
/// Colour-like properties (`color`, `tint`, `borderRadius`, `boxShadow`) are
/// not scalar, so they have no velocity and are not listed.
enum NibProperty {
  /// Horizontal translation in logical pixels (`NibAnim.x`).
  x,

  /// Vertical translation in logical pixels (`NibAnim.y`).
  y,

  /// Horizontal scale (`NibAnim.scaleX`, or `scale`).
  scaleX,

  /// Vertical scale (`NibAnim.scaleY`, or `scale`).
  scaleY,

  /// Rotation around Z in turns (`NibAnim.rotate`).
  rotate,

  /// Horizontal shear in radians (`NibAnim.skewX`).
  skewX,

  /// Vertical shear in radians (`NibAnim.skewY`).
  skewY,

  /// Rotation around X in turns (`NibAnim.rotateX`).
  rotateX,

  /// Rotation around Y in turns (`NibAnim.rotateY`).
  rotateY,

  /// Gaussian blur sigma (`NibAnim.blur`).
  blur,

  /// Opacity, `0..1` (`NibAnim.opacity`).
  opacity,
}
