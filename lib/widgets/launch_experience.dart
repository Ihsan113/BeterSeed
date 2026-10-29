import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Separate from habit/garden storage so a welcome screen never resets user
/// progress, water, purchased cosmetics or locally backed-up data.
const onboardingCompletedPreference = 'betterseed_onboarding_completed_v1';

const _navy = Color(0xFF071B22);
const _mint = Color(0xFF9EF7BD);
const _blue = Color(0xFF80DFFF);
const _backdrop = 'assets/images/backgrounds/enchanted_valley.webp';
const _sprout = 'assets/images/trees/stage_1_sprout.webp';
const _sapling = 'assets/images/trees/stage_2_sapling.webp';

/// Production startup flow. The caller supplies the existing garden widget,
/// keeping this file independent of business logic and Android native code.
class BetterSeedLaunchFlow extends StatefulWidget {
  const BetterSeedLaunchFlow({
    super.key,
    required this.gardenBuilder,
    this.minimumSplashDuration = const Duration(milliseconds: 1500),
  });

  final Widget Function(VoidCallback replayWelcomeGuide) gardenBuilder;
  final Duration minimumSplashDuration;

  @override
  State<BetterSeedLaunchFlow> createState() => _BetterSeedLaunchFlowState();
}

enum _LaunchPage { splash, welcome, garden }

class _BetterSeedLaunchFlowState extends State<BetterSeedLaunchFlow>
    with SingleTickerProviderStateMixin {
  _LaunchPage _page = _LaunchPage.splash;
  late final AnimationController _glow;
  PageController _slides = PageController();
  int _index = 0;
  SharedPreferences? _prefs;

  static const _intro = <_IntroSlide>[
    _IntroSlide(
      label: 'WELCOME',
      title: 'Grow one step at a time',
      detail: 'Small habits can become something beautiful. Welcome to your own peaceful garden.',
      artwork: _sprout,
    ),
    _IntroSlide(
      label: 'DAILY HABITS',
      title: 'Build gentle daily habits',
      detail: 'Complete your checklist and earn water for every daily win.',
      artwork: '',
    ),
    _IntroSlide(
      label: 'YOUR GARDEN',
      title: 'Earn water. Nurture your tree.',
      detail: 'Use your water to grow your tree and unlock new stages, one step at a time.',
      artwork: _sapling,
    ),
    _IntroSlide(
      label: 'FOCUS & AMBIENCE',
      title: 'Relax in your own garden',
      detail: 'Enjoy the moonlit scenery, gentle music and soothing nature sounds.',
      artwork: _sprout,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat(reverse: true);
    _initialize();
  }

  Future<void> _initialize() async {
    // The minimum display interval starts immediately, while preferences are
    // read in parallel. Never pause the garden for a fixed delay *after* loading.
    final duration = Future<void>.delayed(widget.minimumSplashDuration);
    bool hasSeenIntro = false;
    try {
      _prefs = await SharedPreferences.getInstance();
      hasSeenIntro = _prefs?.getBool(onboardingCompletedPreference) ?? false;
    } catch (_) {
      // Storage can be temporarily unavailable: the app must still open.
    }
    await duration;
    if (!mounted) return;
    _glow.stop();
    setState(() => _page = hasSeenIntro ? _LaunchPage.garden : _LaunchPage.welcome);
  }

  void _next() {
    if (_index == _intro.length - 1) {
      _finish();
    } else {
      _slides.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    // Persist once; never touch the user's habits, progress or backup keys.
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(onboardingCompletedPreference, true);
    } catch (_) {
      // If storage fails, entering the garden is still allowed.
    }
    if (!mounted) return;
    setState(() => _page = _LaunchPage.garden);
  }

  void _replayWelcomeGuide() {
    if (!mounted || _page != _LaunchPage.garden) return;
    // Recreate the controller to avoid reopening at the last onboarding page.
    _slides.dispose();
    _slides = PageController();
    setState(() {
      _index = 0;
      _page = _LaunchPage.welcome;
    });
  }

  @override
  void dispose() {
    _slides.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_page) {
      case _LaunchPage.garden:
        return widget.gardenBuilder(_replayWelcomeGuide);
      case _LaunchPage.splash:
        return _scenicScaffold(
          key: const ValueKey('launch-splash'),
          child: _buildSplash(context),
        );
      case _LaunchPage.welcome:
        return _scenicScaffold(
          key: const ValueKey('launch-onboarding'),
          child: _buildIntro(context),
        );
    }
  }

  Widget _scenicScaffold({required Key key, required Widget child}) => Scaffold(
        key: key,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(_backdrop, fit: BoxFit.cover, alignment: Alignment.center),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB008182A), Color(0x7E071B22), Color(0xEF071B22)],
                  stops: [0, .43, 1],
                ),
              ),
            ),
            SafeArea(child: child),
          ],
        ),
      );

  Widget _buildSplash(BuildContext context) => LayoutBuilder(
        builder: (context, c) => Column(
          children: [
            const Spacer(flex: 2),
            AnimatedBuilder(
              animation: _glow,
              builder: (_, child) => Transform.scale(
                scale: 0.96 + _glow.value * .06,
                child: Opacity(opacity: .85 + _glow.value * .15, child: child),
              ),
              child: Image.asset(
                'assets/icon_512.png',
                key: const ValueKey('launch-logo'),
                width: math.min(c.maxWidth * .24, 100.0),
                height: math.min(c.maxWidth * .24, 100.0),
              ),
            ),
            const SizedBox(height: 16),
            const Text('BetterSeed',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 33, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Grow one step at a time',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFFD2E8DC))),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _glow,
              builder: (_, __) => SizedBox(
                height: math.min(220.0, c.maxHeight * .28),
                child: Transform.scale(
                  scale: 0.97 + _glow.value * .06,
                  child: Image.asset(_sprout, fit: BoxFit.contain),
                ),
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Preparing your calm garden...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            const Text('A moment to breathe. A space to grow.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFFCEE2DC))),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _glow,
              builder: (_, __) => Row(
                key: const ValueKey('launch-loading-dots'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => Container(
                  width: 7.0 + (i == (_glow.value * 4).floor().clamp(0, 3) ? 3.0 : 0.0),
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: i == (_glow.value * 4).floor().clamp(0, 3)
                        ? _mint : const Color(0x667A9B91),
                    borderRadius: BorderRadius.circular(8),
                  ),
                )),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.headphones_rounded, size: 16, color: _mint),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text('Tip: best enjoyed with headphones',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFD3E6DD), fontSize: 12)),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      );

  Widget _buildIntro(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                children: [
                  const Icon(Icons.spa_rounded, color: _mint, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('BetterSeed',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  TextButton(
                    key: const ValueKey('onboarding-skip'),
                    onPressed: _finish,
                    child: const Text('Skip', style: TextStyle(color: Color(0xFFE5F1E9))),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: const ValueKey('onboarding-pages'),
                controller: _slides,
                itemCount: _intro.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) => _buildIntroSlide(
                  _intro[index], constraints.maxHeight,
                  index,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_intro.length, (index) => AnimatedContainer(
                key: ValueKey('onboarding-dot-$index'),
                duration: const Duration(milliseconds: 230),
                width: index == _index ? 26 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index == _index ? _mint : const Color(0x887C9B95),
                  borderRadius: BorderRadius.circular(10),
                ),
              )),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const ValueKey('onboarding-next'),
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: _mint,
                    foregroundColor: _navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                  ),
                  child: Text(_index == _intro.length - 1 ? 'Enter Garden' : 'Next',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildIntroSlide(_IntroSlide item, double viewportHeight, int index) =>
      SingleChildScrollView(
        key: ValueKey('onboarding-slide-$index'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(item.label, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                    letterSpacing: 2.0, color: _mint)),
            const SizedBox(height: 13),
            Text(item.title, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800,
                    height: 1.12)),
            const SizedBox(height: 9),
            Text(item.detail, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13,
                    color: Color(0xFFE0EDE6), height: 1.45)),
            const SizedBox(height: 18),
            if (index == 1)
              _habitExamples()
            else
              SizedBox(
                height: math.max(130.0, math.min(270.0, viewportHeight * .35)),
                child: Image.asset(item.artwork, fit: BoxFit.contain),
              ),
            if (index == 2) ...[
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.water_drop_rounded, color: _blue, size: 18),
                  SizedBox(width: 7),
                  Flexible(child: Text('Complete habits → earn water → grow',
                      style: TextStyle(color: Color(0xFFE1F7E9), fontSize: 12))),
                ],
              ),
            ],
            if (index == 3) ...[
              const SizedBox(height: 4),
              Container(
                key: const ValueKey('onboarding-headphone-tip'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xED102C31),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x6678CBA8)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.headphones_rounded, color: _mint, size: 27),
                    SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Best experienced with headphones',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        SizedBox(height: 3),
                        Text('Optional. You can enjoy BetterSeed without them, too.',
                            style: TextStyle(color: Color(0xFFCFDFD8), fontSize: 11)),
                      ],
                    )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      );

  Widget _habitExamples() => Container(
        key: const ValueKey('onboarding-habit-examples'),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xE7102C31),
          border: Border.all(color: const Color(0x667AC5A4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            _WelcomeHabit(icon: Icons.local_drink_outlined, title: 'Drink water', note: 'Stay hydrated', checked: true),
            Divider(height: 1, color: Color(0x336B9D90)),
            _WelcomeHabit(icon: Icons.directions_walk_rounded, title: 'Take a walk', note: 'Move your body'),
            Divider(height: 1, color: Color(0x336B9D90)),
            _WelcomeHabit(icon: Icons.menu_book_outlined, title: 'Read a book', note: 'Feed your mind'),
          ],
        ),
      );
}

class _IntroSlide {
  const _IntroSlide({
    required this.label,
    required this.title,
    required this.detail,
    required this.artwork,
  });

  final String label;
  final String title;
  final String detail;
  final String artwork;
}

class _WelcomeHabit extends StatelessWidget {
  const _WelcomeHabit({
    required this.icon,
    required this.title,
    required this.note,
    this.checked = false,
  });

  final IconData icon;
  final String title;
  final String note;
  final bool checked;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: _blue, size: 24),
            const SizedBox(width: 13),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(note, style: const TextStyle(fontSize: 11, color: Color(0xFFCEDFD7))),
              ],
            )),
            Icon(checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                size: 22, color: checked ? _mint : const Color(0xFF7EAAA1)),
          ],
        ),
      );
}
