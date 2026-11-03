import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nib_motion/nib_motion.dart';

import 'registry.dart';
import 'fullscreen.dart';
import 'review.dart';
import 'scope.dart';
import 'source_link.dart';

const _amber = Color(0xFFF5AB38);

/// Interactive NibMotion gallery, also used by the original demos entry point.
class DemosApp extends StatefulWidget {
  /// Creates the gallery. [initialPath] is useful for embedding and tests.
  const DemosApp({super.key, this.initialPath});

  /// Optional route override; normal browser launches use the address bar.
  final String? initialPath;

  @override
  State<DemosApp> createState() => _DemosAppState();
}

class _DemosAppState extends State<DemosApp> {
  late final GalleryRouter _router = GalleryRouter();
  late final PlatformRouteInformationProvider? _routeProvider =
      widget.initialPath == null
          ? null
          : PlatformRouteInformationProvider(
              initialRouteInformation:
                  RouteInformation(uri: Uri.parse(widget.initialPath!)),
            );
  bool _dark = true;
  bool? _reduced;

  @override
  void dispose() {
    _router.dispose();
    _routeProvider?.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(seedColor: _amber, brightness: brightness)
            .copyWith(
      primary: dark ? _amber : const Color(0xFF875000),
      onPrimary: dark ? const Color(0xFF251A08) : Colors.white,
      surface: dark ? const Color(0xFF18191C) : const Color(0xFFFAF7F0),
      onSurface: dark ? const Color(0xFFF6F2EA) : const Color(0xFF242321),
      surfaceContainerLow: dark ? const Color(0xFF202125) : Colors.white,
      outlineVariant: dark ? const Color(0xFF383A40) : const Color(0xFFDDD9D0),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
      chipTheme: ChipThemeData(side: BorderSide(color: scheme.outlineVariant)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _router._options = _GalleryOptions(
      dark: _dark,
      reduced: _reduced,
      onTheme: () => setState(() => _dark = !_dark),
      onReduced: (value) => setState(() => _reduced = value),
    );
    return MaterialApp.router(
      title: 'NibMotion · Motion that follows your UI',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      routerDelegate: _router,
      routeInformationParser: const GalleryRouteParser(),
      routeInformationProvider: _routeProvider,
      builder: (context, child) => NibMotionConfig(
        reducedMotion: _reduced,
        entranceWarmup: Duration.zero,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
              disableAnimations:
                  _reduced ?? MediaQuery.of(context).disableAnimations),
          child: child!,
        ),
      ),
    );
  }
}

class _GalleryOptions {
  const _GalleryOptions(
      {required this.dark,
      required this.reduced,
      required this.onTheme,
      required this.onReduced});
  final bool dark;
  final bool? reduced;
  final VoidCallback onTheme;
  final ValueChanged<bool?> onReduced;
}

/// URL parser using Flutter's default hash strategy on the web.
class GalleryRouteParser extends RouteInformationParser<String> {
  /// Creates the parser.
  const GalleryRouteParser();

  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture(routeInformation.uri.path);

  @override
  RouteInformation restoreRouteInformation(String configuration) =>
      RouteInformation(uri: Uri.parse(configuration));
}

/// One persistent shell; only the selected example is mounted.
class GalleryRouter extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  String _path = '/';
  final _shellKey = GlobalKey<_GalleryShellState>();
  late _GalleryOptions _options;

  @override
  String get currentConfiguration => _path;

  /// Navigates to the overview or a stable example slug.
  void go(String? slug) {
    _path = slug == null ? '/' : '/demo/$slug';
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(String configuration) async {
    _path = configuration.isEmpty ? '/' : configuration;
    notifyListeners();
  }

  @override
  Future<bool> popRoute() async {
    if (await navigatorKey.currentState?.maybePop() ?? false) {
      return true;
    }
    if (await _shellKey.currentState?._demoNavigator.currentState?.maybePop() ??
        false) {
      return true;
    }
    if (_path == '/') {
      return false;
    }
    go(null);
    return true;
  }

  @override
  Widget build(BuildContext context) => Navigator(
        key: navigatorKey,
        pages: [
          MaterialPage<void>(
              key: const ValueKey('gallery'),
              child: _GalleryShell(
                  key: _shellKey, router: this, options: _options))
        ],
        onDidRemovePage: (_) {},
      );
}

class _GalleryShell extends StatefulWidget {
  const _GalleryShell({super.key, required this.router, required this.options});
  final GalleryRouter router;
  final _GalleryOptions options;

  @override
  State<_GalleryShell> createState() => _GalleryShellState();
}

class _GalleryShellState extends State<_GalleryShell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  GlobalKey<NavigatorState> _demoNavigator = GlobalKey<NavigatorState>();
  String? _activeDemo;
  final _search = TextEditingController();
  String _category = 'All examples';
  int _replay = 0;
  int _importRevision = 0;
  bool _reviewMode = false;
  Map<String, DemoReview> _reviews = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DemoEntry? get _selected =>
      widget.router.currentConfiguration.startsWith('/demo/')
          ? entryForSlug(widget.router.currentConfiguration.substring(6))
          : null;
  List<String> get _categories => [
        'All examples',
        ...{for (final e in galleryEntries) e.category}
      ];
  List<DemoEntry> get _visible => galleryEntries
      .where((e) =>
          (_category == 'All examples' || e.category == _category) &&
          '${e.title} ${e.subtitle} ${e.category}'
              .toLowerCase()
              .contains(_search.text.toLowerCase().trim()))
      .toList();

  void _navigate(String? slug) {
    _scaffold.currentState?.closeDrawer();
    Router.navigate(context, () => widget.router.go(slug));
  }

  Future<void> _enterFullscreen() async {
    final entered = await enterPresentationFullscreen();
    if (!entered && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Fullscreen unavailable. Try your browser’s fullscreen command.'),
      ));
    }
  }

  void _source(DemoEntry entry) {
    if (openSourceUrl(entry.sourceUrl)) return;
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Example source'),
              content: SelectableText(entry.sourceUrl),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            ));
  }

  Future<void> _export() async {
    final text = exportReviews(_reviews, galleryEntries.map((e) => e.slug));
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Export owner review'),
              content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(child: SelectableText(text))),
              actions: [
                TextButton(
                    onPressed: () async {
                      var message =
                          'Review JSON copied. Save it before leaving.';
                      try {
                        await Clipboard.setData(ClipboardData(text: text));
                      } on PlatformException {
                        message =
                            'Copy unavailable. Select the JSON and copy it manually.';
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(message)));
                      }
                    },
                    child: const Text('Copy JSON')),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            ));
  }

  Future<void> _import() async {
    var source = '';
    String? error;
    final result = await showDialog<Map<String, DemoReview>>(
        context: context,
        builder: (context) => StatefulBuilder(
              builder: (context, update) => AlertDialog(
                title: const Text('Import owner review'),
                content: SizedBox(
                    width: 560,
                    child: TextField(
                        onChanged: (value) => source = value,
                        maxLines: 10,
                        decoration: InputDecoration(
                            labelText: 'Paste exported JSON',
                            errorText: error))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        try {
                          Navigator.pop(
                              context,
                              importReviews(source,
                                  galleryEntries.map((e) => e.slug).toSet()));
                        } on FormatException catch (e) {
                          update(() => error = e.message.toString());
                        }
                      },
                      child: const Text('Import'))
                ],
              ),
            ));
    if (result != null && mounted) {
      setState(() {
        _reviews = {..._reviews, ...result};
        _importRevision++;
      });
    }
  }

  Widget _brand() => Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/nib-logo.png',
                width: 52,
                height: 36,
                fit: BoxFit.cover,
                semanticLabel: 'Nib logo')),
        const SizedBox(width: 12),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NibMotion',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.5)),
          Text('INTERACTIVE GALLERY',
              style: TextStyle(fontSize: 9, letterSpacing: 1.5)),
        ])),
      ]);

  Widget _navigation() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
        child: Container(
      width: 284,
      decoration: BoxDecoration(
          border: Border(right: BorderSide(color: scheme.outlineVariant))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 20, 26),
            child: _brand()),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey('gallery-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  labelText: 'Search examples',
                  prefixIcon: Icon(Icons.search, size: 20)),
            )),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Category'),
              child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                isDense: true,
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(
                        value: category,
                        child: Text(category,
                            style: const TextStyle(fontSize: 13)))
                ],
                onChanged: (value) => setState(() => _category = value!),
              ))),
        ),
        const SizedBox(height: 16),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListTile(
              leading: const Icon(Icons.grid_view_rounded, size: 20),
              title: const Text('Overview'),
              selected: _selected == null,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onTap: () => _navigate(null),
            )),
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text('${_visible.length} EXAMPLES',
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: scheme.onSurfaceVariant))),
        Expanded(
            child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          itemCount: _visible.length,
          itemBuilder: (context, index) {
            final entry = _visible[index];
            return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: ListTile(
                  key: ValueKey('nav-${entry.slug}'),
                  dense: true,
                  minTileHeight: 48,
                  title:
                      Text(entry.title, style: const TextStyle(fontSize: 13)),
                  selected: _selected?.slug == entry.slug,
                  selectedTileColor: scheme.primary.withValues(alpha: .12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  trailing: _reviewMode
                      ? Icon(
                          _reviews[entry.slug]?.status == ReviewStatus.approved
                              ? Icons.check_circle_outline
                              : Icons.circle_outlined,
                          size: 14)
                      : null,
                  onTap: () => _navigate(entry.slug),
                ));
          },
        )),
        Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
                'Built with Flutter + nib_motion\nEvery example runs live.',
                style: TextStyle(
                    fontSize: 11,
                    height: 1.7,
                    color: scheme.onSurfaceVariant))),
      ]),
    ));
  }

  Widget _toolbar(bool wide) => Container(
        height: 72,
        padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 12),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant))),
        child: Row(children: [
          if (!wide)
            IconButton(
                tooltip: 'Open example navigation',
                onPressed: () => _scaffold.currentState!.openDrawer(),
                icon: const Icon(Icons.menu)),
          Expanded(
              child: Text(_selected?.category ?? 'Explore the motion system',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13))),
          if (supportsPresentationFullscreen)
            IconButton(
                tooltip: 'Enter presentation fullscreen (Esc to leave)',
                onPressed: _enterFullscreen,
                icon: const Icon(Icons.fullscreen)),
          IconButton(
              tooltip:
                  widget.options.dark ? 'Use light theme' : 'Use dark theme',
              onPressed: widget.options.onTheme,
              icon: Icon(widget.options.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined)),
          PopupMenuButton<String>(
            tooltip: 'Motion preference',
            icon: Icon(widget.options.reduced == true
                ? Icons.motion_photos_off_outlined
                : Icons.motion_photos_on_outlined),
            onSelected: (value) => widget.options
                .onReduced(value == 'system' ? null : value == 'reduce'),
            itemBuilder: (context) => [
              for (final item in [
                ('system', 'Use system motion preference'),
                ('reduce', 'Reduce motion'),
                ('full', 'Full motion')
              ])
                CheckedPopupMenuItem(
                    value: item.$1,
                    checked: widget.options.reduced ==
                        (item.$1 == 'system' ? null : item.$1 == 'reduce'),
                    child: Text(item.$2)),
            ],
          ),
          IconButton(
              tooltip: _reviewMode ? 'Hide owner review' : 'Show owner review',
              isSelected: _reviewMode,
              onPressed: () => setState(() => _reviewMode = !_reviewMode),
              icon: const Icon(Icons.fact_check_outlined)),
        ]),
      );

  Widget _overview(BoxConstraints constraints) {
    final scheme = Theme.of(context).colorScheme;
    final roomy = constraints.maxWidth > 700;
    return ListView(padding: EdgeInsets.all(roomy ? 40 : 20), children: [
      NibMotion(
          initial: const NibAnim(opacity: 0, y: 12),
          animate: const NibAnim(opacity: 1, y: 0),
          transition: NibTransition.springSnappy,
          child: Container(
            padding: EdgeInsets.all(roomy ? 36 : 24),
            decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('FLUTTER MOTION, IN YOUR HANDS',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: scheme.primary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 22),
              Text('Motion that\nfollows your UI.',
                  style: TextStyle(
                      fontSize: roomy ? 54 : 36,
                      height: 1.08,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2)),
              const SizedBox(height: 20),
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                      'Change direction mid-flight. Drag past the edge. Rearrange a layout. Explore a single motion system through real, responsive examples.',
                      style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: scheme.onSurfaceVariant))),
              const SizedBox(height: 28),
              Wrap(spacing: 12, runSpacing: 12, children: [
                FilledButton.icon(
                    onPressed: () => _navigate('interruption'),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Try interruptible springs')),
                OutlinedButton.icon(
                    onPressed: () => _navigate('daily-focus'),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Explore Daily Focus')),
              ]),
              const SizedBox(height: 24),
              Text(
                  '${demoEntries.length} original demos  /  ${galleryEntries.length} live examples  /  Open source',
                  style:
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ]),
          )),
      const SizedBox(height: 36),
      Row(children: [
        Expanded(
            child: Text(
                _category == 'All examples'
                    ? 'Find your next interaction'
                    : _category,
                style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.5))),
        Text('${_visible.length} examples',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))
      ]),
      const SizedBox(height: 16),
      if (_visible.isEmpty)
        const Padding(
            padding: EdgeInsets.all(24),
            child:
                Text('No matching examples. Try another search or category.')),
      LayoutBuilder(builder: (context, c) {
        final columns = c.maxWidth > 1000
            ? 3
            : c.maxWidth > 620
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: 190,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16),
          itemCount: _visible.length,
          itemBuilder: (context, index) {
            final entry = _visible[index];
            return Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: ValueKey('card-${entry.slug}'),
                onTap: () => _navigate(entry.slug),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(_categoryIcon(entry.category),
                              size: 22, color: scheme.primary),
                          const Spacer(),
                          const Icon(Icons.arrow_outward, size: 18)
                        ]),
                        const Spacer(),
                        Text(entry.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 17)),
                        const SizedBox(height: 8),
                        Text(entry.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: scheme.onSurfaceVariant)),
                      ]),
                ),
              ),
            );
          },
        );
      }),
      if (_reviewMode) _reviewTools(),
      const SizedBox(height: 32),
    ]);
  }

  Widget _reviewTools() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Owner review',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(
            'Decisions stay in this session. Export before refreshing or closing the page.'),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 8, children: [
          OutlinedButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export JSON')),
          OutlinedButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import JSON')),
        ]),
      ]));

  Widget _detail(DemoEntry entry, BoxConstraints constraints) {
    final identity = '${entry.slug}-$_replay';
    if (_activeDemo != identity) {
      _activeDemo = identity;
      _demoNavigator = GlobalKey<NavigatorState>();
    }
    final wide = constraints.maxWidth > 700;
    final scheme = Theme.of(context).colorScheme;
    final index = galleryEntries.indexOf(entry);
    final review = _reviews[entry.slug] ?? const DemoReview();
    return ListView(
        key: ValueKey('detail-${entry.slug}'),
        padding: EdgeInsets.all(wide ? 32 : 16),
        children: [
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                  key: const ValueKey('back-to-gallery'),
                  onPressed: () => _navigate(null),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('All examples'))),
          const SizedBox(height: 12),
          Text(entry.title,
              style: TextStyle(
                  fontSize: wide ? 34 : 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.8)),
          const SizedBox(height: 8),
          Text(entry.subtitle,
              style: TextStyle(
                  fontSize: 15, height: 1.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
                key: const ValueKey('replay-demo'),
                onPressed: () => setState(() => _replay++),
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('Replay / reset')),
            OutlinedButton.icon(
                onPressed: () => _source(entry),
                icon: const Icon(Icons.code, size: 18),
                label: const Text('View source')),
          ]),
          const SizedBox(height: 18),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.touch_app_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(entry.instructions,
                        style: const TextStyle(fontSize: 13, height: 1.5)))
              ])),
          if (entry.notice != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(entry.notice!,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurfaceVariant))),
          const SizedBox(height: 20),
          Container(
            height: math.max(520, constraints.maxHeight - 300),
            decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant)),
            clipBehavior: Clip.antiAlias,
            child: GalleryDemoScope(
                child: Navigator(
              key: _demoNavigator,
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => entry.builder()),
            )),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: index == 0
                            ? null
                            : () => _navigate(galleryEntries[index - 1].slug),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Previous')))),
            Text('${index + 1} / ${galleryEntries.length}',
                style: const TextStyle(fontSize: 12)),
            Expanded(
                child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                        onPressed: index == galleryEntries.length - 1
                            ? null
                            : () => _navigate(galleryEntries[index + 1].slug),
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Next')))),
          ]),
          if (_reviewMode) ...[
            _reviewTools(),
            Wrap(spacing: 10, runSpacing: 8, children: [
              for (final status in ReviewStatus.values)
                ChoiceChip(
                  label: Text(status.label),
                  selected: review.status == status,
                  onSelected: (_) => setState(() => _reviews[entry.slug] =
                      DemoReview(
                          status: status,
                          notes: (_reviews[entry.slug] ?? review).notes)),
                )
            ]),
            const SizedBox(height: 12),
            TextFormField(
                key: ValueKey('notes-${entry.slug}-$_importRevision'),
                initialValue: review.notes,
                maxLines: 4,
                maxLength: 10000,
                decoration: const InputDecoration(
                    labelText: 'Review notes',
                    hintText: 'What worked? What needs another pass?'),
                onChanged: (notes) => _reviews[entry.slug] = DemoReview(
                    status: (_reviews[entry.slug] ?? review).status,
                    notes: notes)),
          ],
        ]);
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        final selected = _selected;
        final unknown =
            selected == null && widget.router.currentConfiguration != '/';
        return Scaffold(
          key: _scaffold,
          drawer: wide ? null : Drawer(width: 300, child: _navigation()),
          body: Row(children: [
            if (wide) _navigation(),
            Expanded(
                child: Column(children: [
              _toolbar(wide),
              Expanded(
                  child: LayoutBuilder(
                      builder: (context, constraints) => unknown
                          ? Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  const Text('Example not found'),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                      onPressed: () => _navigate(null),
                                      child: const Text('Return to gallery'))
                                ]))
                          : selected == null
                              ? _overview(constraints)
                              : _detail(selected, constraints))),
            ])),
          ]),
        );
      });
}

IconData _categoryIcon(String category) => switch (category) {
      'Physics & gestures' => Icons.gesture,
      'Layout & presence' => Icons.dashboard_outlined,
      'Scroll & navigation' => Icons.swap_vert,
      'Timelines & orchestration' => Icons.timeline,
      'Effects & shaders' => Icons.blur_on,
      'Developer tools' => Icons.tune,
      'Accessibility' => Icons.accessibility_new,
      'Applications' => Icons.apps,
      _ => Icons.motion_photos_on_outlined,
    };
