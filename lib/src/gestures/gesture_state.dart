/// The interaction state that determines which `NibAnim` a `NibMotion`
/// widget is currently animating toward.
///
/// Priority when multiple states are active simultaneously is
/// `drag > tap > hover > focus > none`.
enum NibGestureState {
  /// No active interaction; animating toward `animate` (or `initial`).
  none,

  /// The pointer is hovering; animating toward `whileHover`.
  hover,

  /// The widget is being pressed; animating toward `whileTap`.
  tap,

  /// The widget has input focus; animating toward `whileFocus`.
  focus,

  /// The widget is being dragged; animating toward `whileDrag`.
  drag,
}
