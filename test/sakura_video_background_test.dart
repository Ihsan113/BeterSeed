import 'package:betterseed/widgets/local_pack_video_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('A remote video has a local file-aware poster when motion is disabled',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: LocalPackVideoBackground(
        video: 'assets/videos/sakura_loop_5s.mp4',
        poster: 'assets/images/backgrounds/enchanted_valley.webp',
        animate: false,
      )),
    ));
    expect(find.byKey(const ValueKey('local-pack-video-poster')), findsOneWidget);
    final poster = tester.widget<Image>(find.byKey(const ValueKey('local-pack-video-poster')));
    expect(poster.fit, BoxFit.cover);
    expect(tester.takeException(), isNull);
  });
}
