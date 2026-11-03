---
{
  "id": "text-motion",
  "evidence": "MotionNib/motion/lib/src/text/nib_text.dart; MotionNib/motion/lib/src/text/nib_text_config.dart; MotionNib/motion/lib/src/text/nib_typewriter.dart; MotionNib/motion/lib/src/text/nib_text_gradient.dart; MotionNib/motion/lib/src/text/nib_text_reveal.dart"
}
---

# Text motion

Choose between animated units, typing, a gradient sweep, and a whole-block reveal.

<!-- section: choose-text-primitive -->
## Choose what actually changes

Start with the content job. NibText wraps separate units in NibMotion, so use it when letters, words, or explicit lines should each enter with their own timing. NibTypewriter changes the number of visible characters at discrete timer ticks. NibGradientText keeps the full string laid out and moves a gradient over its painted glyphs. NibTextReveal keeps the whole child laid out and uncovers it with a clip. These are four different behaviors, not four names for the same animation.

A heading that must be readable immediately may need a static Text instead. For a short decorative heading, try NibText with a modest word stagger. For a loading placeholder, do not make a typewriter imply that real data is arriving one character at a time. Choose an effect only after deciding whether users need the complete words at the start, during the effect, or at the end.

All examples below belong inside a Flutter build method unless they explicitly show a State owner. Import package:nib_motion/nib_motion.dart and the Flutter widget or material library used by the surrounding screen. When an example refers to a variable such as phrase or show, that variable comes from the host widget’s state.

<!-- section: character-units -->
## Animate perceived characters

NibTextUnit.character is the default. NibText splits the string into an approximation of grapheme clusters and gives each animated unit a NibMotion child. The splitter keeps UTF-16 surrogate pairs and common combining marks, joiners, skin-tone modifiers, and flag pairs together. It is intentionally dependency-free and is not a complete Unicode grapheme algorithm. Test unfamiliar scripts and emoji sequences before claiming exact per-character treatment.

The first example fades each unit in from 10 logical pixels below its final position. initial is the start state, animate is the target, and staggerDelay adds 35 ms between unit starts. Without animate, the unit remains at initial and no entrance occurs. For longer text, per-character mode creates many children; switch to words or a whole-block reveal when that cost or reading pattern is wrong.

```dart
NibText(
  'Hello 👋',
  config: const NibTextConfig(
    unit: NibTextUnit.character,
    initial: NibAnim(opacity: 0, y: 10),
    animate: NibAnim.identity,
    staggerDelay: Duration(milliseconds: 35),
  ),
)

```

<!-- section: word-units -->
## Keep spaces and move words

NibTextUnit.word splits on whitespace. A run of spaces remains plain, unanimated text between animated word widgets; it is not counted as another stagger step. This is useful for a short slogan because the words remain recognizable while the animation progresses. It also means a string with irregular spaces preserves those spaces rather than normalizing the copy.

Place the example in build and adjust the sentence at different viewport widths. The parent uses Wrap for character and word modes, so words may wrap differently from a single Text paragraph. textAlign changes Wrap alignment, while overflow applies to each unit’s Text rather than providing one overflow rule for the entire assembled sentence. Use ordinary Text for long body copy, selection, and exact paragraph flow.

```dart
NibText(
  'Move with intention',
  textAlign: TextAlign.center,
  config: const NibTextConfig(
    unit: NibTextUnit.word,
    initial: NibAnim(opacity: 0, y: 14),
    animate: NibAnim.identity,
    staggerDelay: Duration(milliseconds: 80),
  ),
)

```

<!-- section: line-units -->
## Use explicit lines, not visual wraps

NibTextUnit.line splits at newline characters in the source string. It does not inspect where a Text widget happens to wrap at a narrow width. The resulting animated units are placed in a Column. Use explicit lines for a two-line title or a planned verse where line boundaries are part of the content. If a responsive title needs different line breaks at different widths, choose the string for that width in the host widget.

Try the example at phone and desktop widths. Changing textAlign affects the Column cross-axis alignment, but it cannot make an overlong line fit. A line may still wrap inside its own Text. Check that the visual order and screen-reader order stay sensible when you swap the line text or font size.

```dart
NibText(
  'Build a little.\nMake it move.',
  textAlign: TextAlign.center,
  config: const NibTextConfig(
    unit: NibTextUnit.line,
    initial: NibAnim(opacity: 0, x: -18),
    animate: NibAnim.identity,
    staggerDelay: Duration(milliseconds: 140),
  ),
)

```

<!-- section: stagger-origins -->
## Change where the stagger begins

staggerFrom has four choices. start delays animated unit i by i × staggerDelay. end delays it by (count − 1 − i) × staggerDelay. center starts at the middle and spreads outward; for an even count the two middle units have equal delay. random assigns repeatable pseudorandom delays within the overall window, so it is a shuffled entrance rather than a new random order on every frame. Only animated units count: the spaces between words do not.

In the playground, use the same phrase and delay while changing start, end, center, and random. Do not change several settings at once if you want to understand the order. A large stagger multiplied by a long sentence can delay the last unit well beyond the point where a heading should be readable. For essential text, keep the total wait short or present the complete text outside the animation.

```dart
NibText(
  'One two three four',
  config: const NibTextConfig(
    unit: NibTextUnit.word,
    initial: NibAnim(opacity: 0),
    animate: NibAnim.identity,
    staggerDelay: Duration(milliseconds: 90),
    staggerFrom: NibTextStaggerFrom.center,
  ),
)

```

<!-- section: composed-motion -->
## Combine properties on each unit

A NibAnim can change several properties in the same unit. The example combines opacity, vertical translation, scale, and a small Z rotation. x and y are logical-pixel offsets from the natural position; scale 1 is normal size; rotate is measured in turns, so 0.02 is 7.2 degrees, not 0.02 radians. NibAnim.identity restores all of those properties to their resting values.

Begin with opacity and y, then add scale, then rotation. Watch legibility and the visual center as properties combine. Avoid a large blur or rotation on text users must read while it moves. A composed unit animation is still one transition per unit. NibText does not expose a separate transition for each property through NibTextConfig, so split elements into separate widgets if their timing truly needs to differ.

```dart
NibText(
  'Small moves add up',
  config: const NibTextConfig(
    unit: NibTextUnit.word,
    initial: NibAnim(opacity: 0, y: 16, scale: 0.92, rotate: 0.02),
    animate: NibAnim.identity,
    staggerDelay: Duration(milliseconds: 70),
  ),
)

```

<!-- section: spring-vs-tween -->
## Choose a tween or a spring

With config.transition omitted, the current NibText widget builds a 400 ms tween for each unit. The NibTextConfig comment that describes a spring default is stale; the widget implementation is the source of this behavior. Supply NibTransition(duration:, curve:) for predictable timing, or a transition with spring: NibSpringDescription.gentle for velocity-based settling. A spring’s duration and curve do not determine its path.

NibText builds each unit transition from the supplied duration, curve, and spring, but replaces transition.delay with the calculated stagger delay. A delay supplied on config.transition therefore is not an extra initial wait. Put a delay in the host’s mounting logic or another wrapper if the whole text must start later. Compare a 250 ms tween and a gentle spring with the same word stagger; interrupt by changing the host content and check whether the new mount or existing element should replay.

```dart
NibText(
  'Timing changes the mood',
  config: const NibTextConfig(
    unit: NibTextUnit.word,
    initial: NibAnim(opacity: 0, y: 12),
    animate: NibAnim.identity,
    staggerDelay: Duration(milliseconds: 65),
    transition: NibTransition(
      spring: NibSpringDescription.gentle,
    ),
  ),
)

```

<!-- section: typewriter -->
## Type, blink, delete, and repeat

NibTypewriter reveals one approximated grapheme at each speed interval, 50 ms by default. It uses Timer.periodic and setState because the actual content length changes. delay waits before typing begins. cursor defaults to a vertical bar; null removes it. cursorBlinkInterval defaults to 530 ms and controls the visibility toggle when the cursor is active. If repeat is true, the widget pauses briefly at full text, deletes at deleteSpeed (or speed when null), then types again without another onComplete call.

onComplete runs once per mounted widget after the first full reveal, not once per repeat loop. In the current implementation, the last character appears on one tick and completion is checked at the next tick. Updating text on the same mounted widget changes the internal grapheme list and clamps the revealed count; it does not automatically restart typing from zero. Use a deliberate new key if a new phrase must begin from empty, and manage the host’s business completion independently of the decorative typing effect.

```dart
NibTypewriter(
  'Ready when you are.',
  speed: const Duration(milliseconds: 45),
  cursor: '▍',
  cursorBlinkInterval: const Duration(milliseconds: 450),
  delay: const Duration(milliseconds: 200),
  repeat: false,
  onComplete: () {
    // Optional visual follow-up; keep essential actions available earlier.
  },
)

```

<!-- section: gradient -->
## Sweep color over already visible text

NibGradientText lays out the complete string once and masks a Gradient onto the glyphs. Its style supplies font metrics, but the style color is ignored because the gradient colors paint the letters. duration is 2000 ms for one sweep by default, repeat is true, and direction chooses left-to-right or right-to-left travel. The direction parameter does not set the paragraph’s text direction; layout uses the ambient Directionality.

Try repeat: false for an introduction that settles at the final gradient position. A repeating gradient is decorative and keeps a ticker active while mounted. Under reduced motion the ticker stops and a static gradient frame remains. Keep sufficient contrast at every part of the sweep, including when the text sits over a changing background. A changing gradient can cost raster time because painting uses a layer and mask; profile the finished screen if many labels use it.

```dart
NibGradientText(
  'A little color',
  gradient: const LinearGradient(
    colors: [Color(0xFF02569B), Color(0xFF54C5F8)],
  ),
  duration: const Duration(seconds: 2),
  repeat: true,
  direction: TextDirection.ltr,
)

```

<!-- section: reveal -->
## Wipe an entire block from an edge

NibTextReveal takes any child, not only Text, and clips the whole laid-out child from factor zero to one. left shows a growing clip from the left edge, right from the right, up grows from the bottom edge, and down grows from the top. Those physical edge choices do not automatically mirror for RTL; choose the enum from Directionality when the writing direction should change the entrance edge.

The reveal starts on mount. duration defaults to 500 ms, delay to zero, and curve to easeInOut. Its implementation uses an AnimationController tween, despite an outdated comment mentioning SpringSolver. Reduced motion shows the full child immediately. The public controller parameter is currently unconnected: passing a NibMotionController does not attach it and start() cannot replay this reveal. Remounting with a new key can replay an entrance, but treat that as a new widget lifecycle. Test a reduced-motion change during a pending delay because the delayed callback is mounted-guarded rather than canceled.

```dart
NibTextReveal(
  direction: NibTextRevealDirection.up,
  duration: const Duration(milliseconds: 550),
  child: const Text('The whole line appears together'),
)

```

<!-- section: layered-combinations -->
## Layer effects when they serve one message

A reveal can wrap NibGradientText: the outer clip controls when the full glyphs become visible, while the inner gradient has its own ticker and duration. These clocks are independent. Build the gradient child first, then wrap it, and test reduced motion so the complete phrase stays visible as a static gradient. This combination is a useful heading treatment, but it does not certify every renderer or every shader-like blend on every browser.

A NibMotion container can hold NibTypewriter. The container moves once from its initial state while the inner typewriter advances content at timer intervals. Keep the container’s motion short enough that the text is not repeatedly moving away as users try to read. The typewriter onComplete concerns the first full phrase; it does not mean the outer NibMotion finished. Do not tie a form submit, navigation, or authorization decision to either decorative completion callback.

```dart
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    NibTextReveal(
      direction: NibTextRevealDirection.left,
      child: NibGradientText(
        'Reveal the color',
        gradient: const LinearGradient(
          colors: [Color(0xFF02569B), Color(0xFF54C5F8)],
        ),
        repeat: false,
      ),
    ),
    NibMotion(
      initial: const NibAnim(opacity: 0, y: 8),
      animate: NibAnim.identity,
      child: const NibTypewriter('Then type the detail.'),
    ),
  ],
)

```

<!-- section: ownership-and-exit -->
## Know which state and callbacks you own

NibText owns its per-unit NibMotion widgets. If you pass a NibMotionController to NibText, it is forwarded to every animated unit; one start command targets all attached units, and your State owns and disposes that external controller. NibTextConfig.exit is passed into each unit and creates nested presence handling, but removing a whole NibText or replacing its text is not the same as removing one keyed unit from a stable parent. Test the exact exit interaction before promising a staggered text departure.

NibText.rich first calls span.toPlainText(), then applies the one flat style supplied to NibText. Inline span styles and recognizers are not preserved per unit. Use ordinary RichText or another deliberate composition for linked or differently styled phrases. A plain NibTextConfig.copyWith uses ?? for each field: passing null keeps the old nullable initial, animate, exit, or transition; it cannot clear one of them. Construct a new config when you need to remove a value.

NibTextReveal has no working public replay handle at present. NibTypewriter owns and cancels its delay, typing, and blink timers on disposal. NibGradientText owns its ticker and MotionValue and disposes both. Keep State-level keys and controllers only when your screen really needs replay or cross-widget coordination.

<!-- section: accessibility -->
## Keep the words available

Unit motion can produce several Text descendants where a reader expects one phrase. Inspect the semantics tree with TalkBack or VoiceOver rather than assuming the sentence is announced once in the desired order. For a decorative title, a parent Semantics label with inner semantics excluded can expose the complete phrase while its visual units animate. For interactive rich text, this shortcut is insufficient because it would hide link semantics; keep the interactive text as real accessible controls instead.

Reduced motion changes the effects differently. NibText’s internal NibMotion units should settle at the target; NibTypewriter shows all text and reports completion; NibGradientText keeps a static gradient frame; NibTextReveal shows its whole child. Verify the actual screen at both motion settings, especially while changing the setting mid-animation. Do not rely on color or moving letters alone to convey status, and avoid a long stagger before a user can read an instruction.

```dart
Semantics(
  label: 'Move with intention',
  child: ExcludeSemantics(
    child: NibText(
      'Move with intention',
      config: const NibTextConfig(
        unit: NibTextUnit.word,
        initial: NibAnim(opacity: 0),
        animate: NibAnim.identity,
      ),
    ),
  ),
)

```

<!-- section: nib-text-api -->
## NibText and NibTextConfig parameters

Both NibText(text, ...) and NibText.rich(span, ...) accept the same named parameters. The first takes a String; the second takes an InlineSpan that is flattened to plain text. NibTextConfig is immutable. Its defaults alone do not create an entrance because animate is null. The table records the current constructor values; it also applies to a new config built after a host state change.

copyWith accepts unit, initial, animate, exit, staggerDelay, staggerFrom, and transition, with nullable arguments. It returns a new config and uses ?? for each field. Therefore copyWith(animate: null) retains the old animate value rather than clearing it. Use a new NibTextConfig to deliberately clear a nullable field.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| NibText.text | String | required positional in NibText | Source string split into animated units. |
| NibText.rich.span | InlineSpan | required positional in NibText.rich | Flattened with toPlainText before splitting; inline styles are not preserved. |
| NibText.key | Key? | null | Flutter identity; change deliberately to remount and replay. |
| NibText.config | NibTextConfig | const NibTextConfig() | Unit splitting, states, stagger, and transition. |
| NibText.style | TextStyle? | null | Flat base style applied to each unit. |
| NibText.textAlign | TextAlign? | null | Mapped to Wrap or Column alignment. |
| NibText.overflow | TextOverflow? | null | Passed to each unit’s Text, not a paragraph-level ellipsis. |
| NibText.controller | NibMotionController? | null | External handle forwarded to all animated unit widgets. |
| NibTextConfig.unit | NibTextUnit | character | Character approximation, whitespace-delimited word, or explicit newline. |
| NibTextConfig.initial | NibAnim? | null → identity | Starting state for each animated unit. |
| NibTextConfig.animate | NibAnim? | null | Resting target; null means no entrance animation. |
| NibTextConfig.exit | NibAnim? | null | Exit target passed to each unit; verify the surrounding removal lifecycle. |
| NibTextConfig.staggerDelay | Duration | 30 ms | Increment between animated unit starts. |
| NibTextConfig.staggerFrom | NibTextStaggerFrom | start | start, end, center, or repeatable random delays. |
| NibTextConfig.transition | NibTransition? | null → 400 ms tween | Timing for each unit; its delay is replaced by the unit stagger. |
| NibTextConfig.copyWith(...) | NibTextConfig | existing fields retained | Uses ?? for every argument; null cannot clear an existing nullable value. |
| copyWith.unit | NibTextUnit? | null → keep old | Replace the split mode when non-null. |
| copyWith.initial | NibAnim? | null → keep old | Replace the unit start state when non-null. |
| copyWith.animate | NibAnim? | null → keep old | Replace the target when non-null; cannot clear it. |
| copyWith.exit | NibAnim? | null → keep old | Replace the exit target when non-null; cannot clear it. |
| copyWith.staggerDelay | Duration? | null → keep old | Replace the time between animated units. |
| copyWith.staggerFrom | NibTextStaggerFrom? | null → keep old | Replace the stagger origin. |
| copyWith.transition | NibTransition? | null → keep old | Replace the transition when non-null; cannot clear it. |

<!-- section: typewriter-api -->
## NibTypewriter parameters

NibTypewriter changes visible content through timers. It is the text primitive that rebuilds on each discrete reveal or deletion tick. Keep it short and dispose the surrounding route normally; its State cancels its timers. Avoid zero or negative timer intervals in host settings.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| NibTypewriter.text | String | required positional | Full phrase to reveal; changing it in place does not reset the count. |
| NibTypewriter.key | Key? | null | Flutter identity; a new key creates a fresh typing lifecycle. |
| NibTypewriter.speed | Duration | 50 ms | Interval between visible grapheme increments. |
| NibTypewriter.cursor | String? | '\|' | Cursor text; null removes it. |
| NibTypewriter.cursorBlinkInterval | Duration | 530 ms | Visibility toggle interval when a cursor exists. |
| NibTypewriter.style | TextStyle? | null | Applied to revealed text and cursor. |
| NibTypewriter.onComplete | VoidCallback? | null | Called once after first full reveal, including reduced motion. |
| NibTypewriter.repeat | bool | false | Delete and retype indefinitely when true. |
| NibTypewriter.deleteSpeed | Duration? | null → speed | Interval between deletion steps during repeat. |
| NibTypewriter.delay | Duration | Duration.zero | Wait before typing starts. |

<!-- section: effects-api -->
## Gradient and reveal parameters

NibGradientText paints the whole text with a moving gradient. NibTextReveal clips a whole child. Their parameter names overlap only at key; duration measures one gradient sweep in the first widget and one reveal traversal in the second. The reveal controller field is currently inert even though it appears in the constructor.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| NibGradientText.text | String | required positional | Complete laid-out text. |
| NibGradientText.key | Key? | null | Flutter widget identity. |
| NibGradientText.gradient | Gradient | required | Colors masked onto painted glyphs. |
| NibGradientText.style | TextStyle? | null | Font metrics and styling; color is ignored. |
| NibGradientText.duration | Duration | 2000 ms | Time for one sweep. |
| NibGradientText.repeat | bool | true | Whether the sweep loops. |
| NibGradientText.direction | TextDirection | ltr | Sweep travel direction, not paragraph layout direction. |
| NibTextReveal.child | Widget | required | Entire block exposed by the clip. |
| NibTextReveal.key | Key? | null | Flutter identity; remounting can replay entrance. |
| NibTextReveal.direction | NibTextRevealDirection | left | Clip edge: left, right, up from bottom, or down from top. |
| NibTextReveal.duration | Duration | 500 ms | Time for the clip to reach full size. |
| NibTextReveal.delay | Duration | Duration.zero | Wait before starting the reveal. |
| NibTextReveal.curve | Curve | easeInOut | Easing curve of the clip factor. |
| NibTextReveal.controller | NibMotionController? | null | Declared but unconnected in current implementation; cannot replay the reveal. |
