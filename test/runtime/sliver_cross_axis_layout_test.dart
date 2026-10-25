import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  testWidgets('motion keeps lazy sliver cross-axis constraints',
      (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 616,
            height: 400,
            child: CustomScrollView(slivers: [
              SliverList.builder(
                itemCount: 2,
                itemBuilder: (context, index) => NibMotion(
                  initial: const NibAnim(opacity: 0),
                  animate: const NibAnim(opacity: 1),
                  child: SizedBox(key: ValueKey('card-$index'), height: 80),
                ),
              ),
            ]),
          )),
    ));
    expect(tester.getSize(find.byKey(const ValueKey('card-0'))).width, 616);
    expect(tester.getSize(find.byKey(const ValueKey('card-1'))).width, 616);
  });
}
