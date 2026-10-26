// Run alone: flutter test --no-pub -r expanded benchmark/snapshot_churn.dart
// Debug VM wall clock only. These numbers are not build/raster frame times.
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/layout/nib_layout_scope.dart';

void main() {
  testWidgets('detached shared-layout snapshot churn', (tester) async {
    const count = 1000;
    const rounds = 5;
    final owners = List<RenderBox>.generate(
      count,
      (_) => RenderConstrainedBox(
        additionalConstraints:
            const BoxConstraints.tightFor(width: 1, height: 1),
      ),
    );
    final rect = const Rect.fromLTWH(0, 0, 1, 1);
    final recordOnlyUs = <int>[];
    final detachUs = <int>[];
    final rssDeltas = <int>[];

    for (var round = 0; round < rounds; round++) {
      final recordScope = NibLayoutScopeData();
      final recordWatch = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        recordScope.record(i, rect, owners[i]);
      }
      recordWatch.stop();
      expect(recordScope.length, count);
      recordOnlyUs.add(recordWatch.elapsedMicroseconds);
      recordScope.dispose();

      final scope = NibLayoutScopeData();
      final beforeRss = ProcessInfo.currentRss;
      final watch = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        scope.record(i, rect, owners[i]);
        scope.ownerDetached(i, owners[i]);
      }
      watch.stop();
      detachUs.add(watch.elapsedMicroseconds);
      rssDeltas.add(ProcessInfo.currentRss - beforeRss);
      expect(scope.length, count);
      await tester
          .pump(NibLayoutScopeData.maxAge + const Duration(milliseconds: 1));
      expect(scope.length, 0,
          reason: 'timers must release quiet detached snapshots');
      scope.dispose();
    }
    // ignore: avoid_print
    print('SNAPSHOT_CHURN count=$count rounds=$rounds '
        'record_only_us=$recordOnlyUs record_plus_detach_us=$detachUs '
        'rss_delta_bytes=$rssDeltas');
  });
}
