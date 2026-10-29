import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all growth sprites and the backdrop are packaged locally', () {
    const stageNames = ['seed', 'sprout', 'sapling', 'young', 'mature', 'legendary'];
    for (var i = 0; i < stageNames.length; i++) {
      final file = File('assets/images/trees/stage_${i}_${stageNames[i]}.webp');
      expect(file.existsSync(), isTrue, reason: file.path);
      expect(file.lengthSync(), greaterThan(1000));
    }
    expect(File('assets/images/backgrounds/enchanted_valley.webp').existsSync(), isTrue);
    for (final fileName in <String>[
      'butterfly_realistic.png',
      'watering_can_realistic.png',
    ]) {
      final image = File('assets/images/effects/$fileName');
      expect(image.existsSync(), isTrue, reason: image.path);
      expect(image.lengthSync(), greaterThan(1000));
      expect(image.readAsBytesSync().sublist(0, 8),
          <int>[137, 80, 78, 71, 13, 10, 26, 10]); // PNG signature
    }
  });

  test('ambient music and all sound effects exist in OGG format', () {
    for (final name in ['forest_piano', 'tap', 'complete', 'plant', 'growth', 'water']) {
      final file = File('assets/audio/$name.ogg');
      expect(file.existsSync(), isTrue, reason: file.path);
      expect(file.readAsBytesSync().sublist(0, 4), [79, 103, 103, 83]); // OggS
    }
  });
}
