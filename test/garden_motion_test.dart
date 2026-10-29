import 'package:betterseed/logic/garden_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('motion follows the device by default', () {
    expect(shouldAnimateGarden(
      livingGardenEnabled: true,
      systemReducedMotion: true,
      allowWhenSystemReduced: false,
    ), isFalse);
    expect(shouldAnimateGarden(
      livingGardenEnabled: true,
      systemReducedMotion: false,
      allowWhenSystemReduced: false,
    ), isTrue);
  });

  test('explicit override permits garden effects when system disables animation', () {
    expect(shouldAnimateGarden(
      livingGardenEnabled: true,
      systemReducedMotion: true,
      allowWhenSystemReduced: true,
    ), isTrue);
  });

  test('Living garden off always disables effects, even with override', () {
    expect(shouldAnimateGarden(
      livingGardenEnabled: false,
      systemReducedMotion: false,
      allowWhenSystemReduced: true,
    ), isFalse);
    expect(shouldAnimateGarden(
      livingGardenEnabled: false,
      systemReducedMotion: true,
      allowWhenSystemReduced: true,
    ), isFalse);
  });
}
