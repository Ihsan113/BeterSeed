import 'dart:math';

/// A quiet greeting per visit, independent of animation and garden state.
class GardenMessages {
  static const messages = [
    'Grow one step at a time',
    'Small steps, deeper roots',
    'A little care goes a long way',
    'Your pace is enough',
    'Make room for a fresh start',
    'Progress begins with one small habit',
    'Keep showing up for yourself',
    'Let good habits take root',
    'Every little effort counts',
    'Pause, breathe, and grow',
    'Today is another chance to bloom',
    'Steady care brings quiet growth',
    'One kind choice can change your day',
    'Give yourself time to grow',
    'Your garden grows with you',
    'Celebrate the small beginnings',
    'A gentle routine, a stronger you',
    'Plant a little hope today',
    'Start small. Keep going.',
    'There is beauty in slow progress',
  ];
  static String pick({String? excluding, Random? random}) {
    final choices = messages.where((m) => m != excluding).toList();
    return choices[(random ?? Random()).nextInt(choices.length)];
  }
}
