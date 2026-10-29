import 'account/pack_catalog.dart';
import 'data/garden_pack_registry.dart';
import 'data/pack_downloads.dart';
import 'widgets/local_pack_video_background.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account/account_api.dart';
import 'account/cloud_account.dart';
import 'account/account_page.dart';
import 'account/legal_page.dart';
import 'account/play_billing.dart';
import 'audio/ambient_audio.dart';
import 'audio/local_music_files.dart';
import 'backup/backup_snapshot.dart';
import 'backup/local_backup_files.dart';
import 'data/habit.dart';
import 'data/garden_messages.dart';
import 'data/garden_appearance.dart';
import 'logic/growth.dart';
import 'logic/garden_motion.dart';
import 'logic/garden_scene_geometry.dart';
import 'logic/water_progress.dart';
import 'platform/device_features.dart';
import 'widgets/garden_life_painter.dart';
import 'widgets/garden_editor_frame.dart';
import 'widgets/garden_wallpaper_page.dart';
import 'widgets/adaptive_garden_background.dart';
import 'widgets/launch_experience.dart';
import 'widgets/moonlight_ambience_painter.dart';
import 'widgets/shop_page.dart';
import 'widgets/coin_store_page.dart';

const _deepNavy = Color(0xFF071B22);
const _mint = Color(0xFF9EF7BD);
const _gold = Color(0xFFFFD989);
const _blue = Color(0xFF80DFFF);
const _glass = Color(0xDF102C31);
const _stageNames = <String>[
  'A New Seed', 'First Sprout', 'Growing Sapling',
  'Young Tree', 'Thriving Tree', 'Legendary Tree',
];


const _habitIconChoices = <MapEntry<String, IconData>>[
  MapEntry('leaf', Icons.spa_outlined),
  MapEntry('water', Icons.local_drink_outlined),
  MapEntry('book', Icons.menu_book_outlined),
  MapEntry('money', Icons.savings_outlined),
  MapEntry('move', Icons.directions_run_outlined),
  MapEntry('heart', Icons.favorite_outline),
  MapEntry('moon', Icons.nightlight_round),
  MapEntry('meditate', Icons.self_improvement_outlined),
];

enum _SettingsSection { home, soundGarden, routine, gardenProgress, widgetDisplay, backupRestore }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  ));
  runApp(const BetterSeedApp());
}

class BetterSeedApp extends StatelessWidget {
  const BetterSeedApp({super.key, this.showLaunchFlow = true});

  /// Disable only in legacy widget tests that exercise the garden directly.
  final bool showLaunchFlow;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BetterSeed',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: _deepNavy,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _mint,
            brightness: Brightness.dark,
          ),
        ),
        home: showLaunchFlow
            ? BetterSeedLaunchFlow(
                gardenBuilder: (replay) => GrowthHome(onShowWelcomeGuide: replay),
              )
            : const GrowthHome(),
      );
}

class GrowthHome extends StatefulWidget {
  const GrowthHome({super.key, this.onShowWelcomeGuide});

  final VoidCallback? onShowWelcomeGuide;

  @override
  State<GrowthHome> createState() => _GrowthHomeState();
}

class _GrowthHomeState extends State<GrowthHome>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _storageHabits = 'betterseed_habits_v1';
  static const _storageXp = 'betterseed_xp_v1';
  static const _storageDate = 'betterseed_day_v1';
  static const _storageProgress = 'betterseed_water_progress_v3';
  static const _storageMusic = 'betterseed_music_v2';
  static const _storageMusicMode = 'betterseed_music_mode_v1';
  static const _storageSfx = 'betterseed_sfx_v2';
  static const _storageMotion = 'betterseed_motion_v2';
  static const _storageMotionOverride = 'betterseed_game_motion_override_v1';
  static const _storageTreeSkin = 'betterseed_tree_skin_v1';
  static const _storageBackground = 'betterseed_background_skin_v1';
  static const _storageButterfly = 'betterseed_butterfly_skin_v1';
  static const _storageWateringCan = 'betterseed_watering_can_skin_v1';
  static const _storageFirefly = 'betterseed_firefly_skin_v1';
  static const _storageBundle = 'betterseed_active_bundle_v1';
  static const _storageTreePlacements = 'betterseed_tree_placements_v1';
  static const _storageOwnedMoonlight = 'betterseed_owned_moonlight_v1';
  static const _storageOwnedSakura = 'betterseed_owned_sakura_v1';
  static const _storageOwnedAutumn = 'betterseed_owned_autumn_v1';
  static const _storageLeafCoins = 'betterseed_leaf_coins_v1';
  static const _storageDeliveredLeafPurchases = 'betterseed_delivered_leaf_purchases_v1';
  static const _starterHabits = <Habit>[
    Habit(id: 'drink', title: 'Drink water', iconKey: 'water'),
    Habit(id: 'read', title: 'Read 10 pages', iconKey: 'book'),
    Habit(id: 'move', title: 'Move for 15 minutes', iconKey: 'move'),
  ];

  final AmbientAudio _audio = AmbientAudio();
  final CloudAccount _cloud = CloudAccount();
  final PackDownloadService _packs = PackDownloadService();
  late final PackCatalog _catalog = PackCatalog(_cloud.api);
  Set<String> get _ownedPacks => _cloud.signedIn
      ? {'default',...((_cloud.wallet?['packs'] as List?)??[]).cast<String>()}
      : {'default',if(_moonlightOwned)'moonlight',if(_sakuraOwned)'sakura',if(_autumnOwned)'golden_autumn'};
  void _catalogChanged(){if(mounted)setState((){});}
  PlayBilling? _billing;
  bool _unlockBusy = false;
  bool _accountPageOpen = false;
  bool _backupBusy = false;
  List<Habit> _habits = List<Habit>.from(_starterHabits);
  WaterProgress _progress = WaterProgress();
  String _today = todayLocalKey();
  Future<void> _saveQueue = Future<void>.value();
  Timer? _dayTimer;
  int _selectedTab = 0;
  Future<void>? _loadWork;
  bool _loaded = false;
  String _gardenMessage = GardenMessages.pick();
  bool _musicEnabled = true;
  bool _musicImportBusy = false;
  bool _settingsOpen = false;
  String _musicMode = 'default';
  ImportedMusic? _importedMusic;
  bool _effectsEnabled = true;
  bool _motionEnabled = true;
  bool _motionOverride = false;
  bool _systemReduceMotion = false;
  bool _reminderEnabled = false;
  bool _reminderBusy = false;
  ShopLoadout _shopLoadout = ShopLoadout.defaultPack;
  // Preserve cosmetics from a newer APK during progress-only sync. Rendering
  // still uses the safe local fallback; explicitly choosing a look replaces it.
  Map<String, String> _unavailableCosmetics = {};
  void _rememberUnavailableCosmetics(Map data) {
    _unavailableCosmetics = {
      for (final key in ShopLoadout.defaultPack.toJson().keys)
        if (data[key] is String && RegExp(r'^[a-z][a-z0-9_]{0,79}$').hasMatch(data[key] as String) &&
            !GardenPackRegistry.packs.any((p) => p.loadout.toJson()[key] == data[key]))
          key: data[key] as String,
    };
  }
  bool _moonlightOwned = false;
  bool _sakuraOwned = false;
  bool _autumnOwned = false;
  int _leafCoins = 0;
  Set<String> _deliveredLeafPurchases = <String>{};
  bool _focusMode = false;
  bool _assetEditMode = false;
  ShopLoadout? _editLoadout;
  Map<String, GardenTreePlacement> _treePlacements = {};
  Map<String, GardenTreePlacement> _editPlacements = {};
  String _assetEditorPanel = 'position';
  String _editorAdjustment = 'size';
  String _editorAssetCategory = 'background';

  ShopLoadout get _visibleLoadout {
    final wanted = _assetEditMode ? (_editLoadout ?? _shopLoadout) : _shopLoadout;
    // An uninstalled theme must never send Image.asset a missing path.
    // For custom combinations check each selected component independently.
    for (final entry in wanted.toJson().entries) {
      final pack = GardenPackRegistry.forAsset(entry.key, entry.value);
      if (!_packs.installed(pack.id)) return ShopLoadout.defaultPack;
    }
    return wanted;
  }

  GardenAppearance get _appearance => GardenAppearance(_visibleLoadout);
  List<String> get _activeTreeImages => _appearance.treeImages;
  String get _activeBackgroundAsset => _appearance.background;
  String get _activeButterflyAsset => _appearance.butterfly;
  String get _activeWateringCanAsset => _appearance.wateringCan;
  PlantingGround get _activePlantingGround => _appearance.ground;
  FireflyPalette get _activeFireflyPalette => _appearance.fireflies;

  GardenTreePlacement get _visiblePlacement =>
      (_assetEditMode ? _editPlacements : _treePlacements)[_visibleLoadout.backgroundId]
          ?? const GardenTreePlacement();

  late final AnimationController _windController;
  late final AnimationController _waterController;

  bool get _showAnimation => shouldAnimateGarden(
        livingGardenEnabled: _motionEnabled,
        systemReducedMotion: _systemReduceMotion,
        allowWhenSystemReduced: _motionOverride,
      );
  int get _completed => _habits.where((h) => h.completed).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _windController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
      animationBehavior: AnimationBehavior.preserve,
    )..repeat();
    _waterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
      animationBehavior: AnimationBehavior.preserve,
    );
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) => _ensureToday());
    _packs.addListener(_catalogChanged);
    _catalog.addListener(_catalogChanged);
    _loadWork = _load();
    unawaited(_catalog.load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _systemReduceMotion = MediaQuery.disableAnimationsOf(context);
    _applyAnimationPreference();
  }

  void _applyAnimationPreference() {
    if (_showAnimation && _selectedTab == 0) {
      if (!_windController.isAnimating) _windController.repeat();
    } else {
      _windController.stop();
    }
    if (!_showAnimation) _waterController.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _audio.setForeground(true);
      _ensureToday();
      _refreshReminderPermission();
      _cloud.schedule();
      _billing?.retry();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // `inactive` can be a transient dialog/system-overlay event; avoid
      // interrupting music every time a sheet/dialog is opened.
      _audio.setForeground(false);
      _cloud.pause();
    }
  }

  @override
  void dispose() {
    if (_focusMode) {
      // Restore Android system bars if the page is closed while immersed.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _dayTimer?.cancel();
    _cloud.onGarden = null;
    _cloud.onWallet = null;
    _cloud.pause();
    _catalog.removeListener(_catalogChanged);
    _catalog.dispose();
    _packs.removeListener(_catalogChanged);
    _packs.dispose();
    _billing?.dispose();
    _cloud.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _windController.dispose();
    _waterController.dispose();
    _audio.dispose();
    super.dispose();
  }

  /// Immersive Garden viewing. No progress or audio settings are changed.
  Future<void> _setFocusMode(bool enabled) async {
    if (_focusMode == enabled || !mounted) return;
    setState(() => _focusMode = enabled);
    if (enabled) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ));
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ));
    }
  }

  Future<void> _load() async {
    try { await _packs.initialize(); } catch (_) { /* Original Garden remains available. */ }
    final prefs = await SharedPreferences.getInstance();
    var loaded = List<Habit>.from(_starterHabits);
    final rawHabits = prefs.getString(_storageHabits);
    if (rawHabits != null) {
      try {
        loaded = (jsonDecode(rawHabits) as List)
            .map((value) => Habit.fromJson(Map<String, dynamic>.from(value as Map)))
            .toList();
      } catch (_) {
        // Preserve app usability on corrupted legacy data.
      }
    }
    final previousMessage = prefs.getString('betterseed_last_message_v1');
    _gardenMessage = GardenMessages.pick(excluding: previousMessage);
    await prefs.setString('betterseed_last_message_v1', _gardenMessage);
    final freshDay = todayLocalKey();
    if (prefs.getString(_storageDate) != freshDay) {
      loaded = loaded.map((habit) => habit.copyWith(completed: false)).toList();
    }
    var progress = WaterProgress(xp: math.max(0, prefs.getInt(_storageXp) ?? 0));
    final rawProgress = prefs.getString(_storageProgress);
    if (rawProgress != null) {
      try {
        progress = WaterProgress.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawProgress) as Map),
        );
      } catch (_) {
        // Legacy XP is retained when a v3 preference is unreadable.
      }
    }
    if (!mounted) return;
    setState(() {
      _habits = loaded;
      _progress = progress;
      _today = freshDay;
      _musicEnabled = prefs.getBool(_storageMusic) ?? true;
      _musicMode = prefs.getString(_storageMusicMode) == 'custom' ? 'custom' : 'default';
      _effectsEnabled = prefs.getBool(_storageSfx) ?? true;
      _motionEnabled = prefs.getBool(_storageMotion) ?? true;
      _motionOverride = prefs.getBool(_storageMotionOverride) ?? false;
      // Migrate previous per-cosmetic preferences into a single full pack.
      // Existing users keep their Moonlight entitlement rather than losing it.
      final legacyMoonlight = <String?>[
        prefs.getString(_storageTreeSkin), prefs.getString(_storageBackground),
        prefs.getString(_storageButterfly), prefs.getString(_storageWateringCan),
        prefs.getString(_storageFirefly),
      ].any((value) => const <String>{
        'moonlight_tree_skin', 'twilight_overlook', 'cosmic_butterfly',
        'celestial_watering_can', 'prism_fireflies',
      }.contains(value));
      final legacyAutumn = <String?>[
        prefs.getString(_storageTreeSkin), prefs.getString(_storageBackground),
        prefs.getString(_storageButterfly), prefs.getString(_storageWateringCan),
        prefs.getString(_storageFirefly),
      ].any((value) => const <String>{
        'golden_autumn_tree_skin', 'golden_autumn_garden', 'amber_butterfly',
        'maple_watering_can', 'ember_fireflies',
      }.contains(value));
      final savedBundle = prefs.getString(_storageBundle);
      _moonlightOwned = (prefs.getBool(_storageOwnedMoonlight) ?? false) || legacyMoonlight;
      _sakuraOwned = prefs.getBool(_storageOwnedSakura) ?? false;
      _autumnOwned = (prefs.getBool(_storageOwnedAutumn) ?? false) || legacyAutumn;
      _leafCoins = math.max(0, prefs.getInt(_storageLeafCoins) ?? 0);
      _deliveredLeafPurchases = (prefs.getStringList(_storageDeliveredLeafPurchases) ?? const <String>[]).toSet();
      _shopLoadout = savedBundle == 'sakura' && _sakuraOwned
          ? ShopLoadout.sakuraPack
          : savedBundle == 'golden_autumn' && _autumnOwned
              ? ShopLoadout.autumnPack
              : (savedBundle == 'moonlight' ||
                  (savedBundle == null && legacyMoonlight))
                  ? ShopLoadout.moonlightPack
                  : (savedBundle == null && legacyAutumn)
                      ? ShopLoadout.autumnPack
                      : ShopLoadout.defaultPack;
      // User-editable cosmetics are independently stored; safely validate
      // unlocked assets before restoring a custom combination.
      if (prefs.getString(_storageTreePlacements) != null) {
        try {
          final raw = jsonDecode(prefs.getString(_storageTreePlacements)!);
          if (raw is Map) {
            _treePlacements = {
              for (final key in raw.keys.whereType<String>().take(200))
                if (RegExp(r'^[a-z][a-z0-9_]{0,79}$').hasMatch(key))
                  key: GardenTreePlacement.fromJson(raw[key]),
            };
          }
        } catch (_) { /* An invalid placement never blocks app startup. */ }
      }
      if (savedBundle != null) {
        _shopLoadout = ShopLoadout.fromMap({
          'treeSkinId': prefs.getString(_storageTreeSkin) ?? _shopLoadout.treeSkinId,
          'backgroundId': prefs.getString(_storageBackground) ?? _shopLoadout.backgroundId,
          'butterflyId': prefs.getString(_storageButterfly) ?? _shopLoadout.butterflyId,
          'wateringCanId': prefs.getString(_storageWateringCan) ?? _shopLoadout.wateringCanId,
          'fireflyId': prefs.getString(_storageFirefly) ?? _shopLoadout.fireflyId,
        }, ownedPacks: _ownedPacks, moonlightOwned: _moonlightOwned, sakuraOwned: _sakuraOwned, autumnOwned: _autumnOwned);
      }
    });
    // Keep account data isolated before the active garden mirror is saved.
    if (_cloud.configured) {
      _cloud.onGarden = _receiveCloudGarden;
      _cloud.onWallet = _receiveCloudWallet;
      await _cloud.initialize(_cloudSnapshot(), _freshCloudSnapshot(), guestWallet: {
        'balance': _leafCoins,
        'packs': [if (_moonlightOwned) 'moonlight', if (_sakuraOwned) 'sakura', if (_autumnOwned) 'golden_autumn'],
      });
      if (!mounted) return;
      _billing = PlayBilling(_cloud)..start();
      if (!_cloud.signedIn && prefs.getBool('betterseed_account_choice_v1') != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _openAccount(initialChoice: true); });
      }
    }
    if (!mounted) return;
    setState(() => _loaded = true);
    _applyAnimationPreference();
    final reminder = await DeviceFeatures.getReminder();
    if (!mounted) return;
    setState(() {
      _reminderEnabled = reminder['enabled'] == true && reminder['permissionGranted'] == true;
    });
    // Resolve an already-imported MP3 after loading preferences. If the file
    // was erased externally, default ambience is always the safe fallback.
    try {
      _importedMusic = await LocalMusicFiles.installedMp3();
    } on PlatformException {
      _importedMusic = null;
    } catch (_) {
      _importedMusic = null;
    }
    if (_musicMode == 'custom' && _importedMusic == null) {
      _musicMode = 'default';
      await prefs.setString(_storageMusicMode, 'default');
    }
    await _audio.initialize(
      music: _musicEnabled,
      effects: _effectsEnabled,
      customMusicPath: _musicMode == 'custom' ? _importedMusic?.path : null,
    );
    if (!mounted) return;
    // Ensure the migrated data has an initialized v3 record and today key.
    _save();
  }

  GardenData _cloudSnapshot() => {
    'version': 1,
    'habits': _habits.map((h) => h.toJson()).toList(),
    'progress': _progress.toJson(),
    'day': _today,
    'cosmetics': {..._shopLoadout.toJson(), ..._unavailableCosmetics},
    'treePlacements': {for (final e in _treePlacements.entries) e.key: e.value.toJson()},
    'preferences': {'music': _musicEnabled, 'effects': _effectsEnabled, 'motion': _motionEnabled, 'motionOverride': _motionOverride},
  };

  GardenData _freshCloudSnapshot() => {
    'version': 1,
    'habits': _starterHabits.map((h) => h.toJson()).toList(),
    'progress': WaterProgress().toJson(), 'day': todayLocalKey(),
    'cosmetics': ShopLoadout.defaultPack.toJson(), 'treePlacements': <String, dynamic>{},
    'preferences': {'music': true, 'effects': true, 'motion': true, 'motionOverride': false},
  };

  void _receiveCloudGarden(GardenData data) {
    if (!mounted) return;
    final prefs = Map<String, dynamic>.from(data['preferences'] as Map);
    final ownership = _cloud.wallet?['packs'] as List?;
    setState(() {
      if (_cloud.signedIn) {
        _moonlightOwned = ownership?.contains('moonlight') == true;
        _sakuraOwned = ownership?.contains('sakura') == true;
        _autumnOwned = ownership?.contains('golden_autumn') == true;
        _leafCoins = (_cloud.wallet?['balance'] as num?)?.toInt() ?? 0;
      }
      final today = todayLocalKey();
      _habits = (data['habits'] as List).map((h) {
        final habit = Habit.fromJson(Map<String, dynamic>.from(h as Map));
        return data['day'] == today ? habit : habit.copyWith(completed: false);
      }).toList();
      _today = today;
      _progress = WaterProgress.fromJson(Map<String, dynamic>.from(data['progress'] as Map));
      _rememberUnavailableCosmetics(data['cosmetics'] as Map);
      _shopLoadout = ShopLoadout.fromMap(Map<String, dynamic>.from(data['cosmetics'] as Map),
        ownedPacks: _ownedPacks, moonlightOwned: _moonlightOwned, sakuraOwned: _sakuraOwned, autumnOwned: _autumnOwned);
      _treePlacements = {for (final e in (data['treePlacements'] as Map).entries) e.key as String: GardenTreePlacement.fromJson(e.value)};
      _musicEnabled = prefs['music'] == true;
      _effectsEnabled = prefs['effects'] == true;
      _motionEnabled = prefs['motion'] == true;
      _motionOverride = prefs['motionOverride'] == true;
      _assetEditMode = false;
      _editLoadout = null;
      _editPlacements = {};
    });
    // Startup restores account preferences before resolving imported music.
    // Let _load initialize audio once its selected file is available.
    if (_loaded) _audio.setMusic(_musicEnabled);
    _audio.setEffects(_effectsEnabled);
    _applyAnimationPreference();
    _save(syncCloud: false);
    SharedPreferences.getInstance().then((p) async {
      await p.setBool(_storageMusic, _musicEnabled);
      await p.setBool(_storageSfx, _effectsEnabled);
      await p.setBool(_storageMotion, _motionEnabled);
      await p.setBool(_storageMotionOverride, _motionOverride);
    });
  }

  void _receiveCloudWallet(GardenData wallet) {
    if (!mounted) return;
    final packs = wallet['packs'] as List;
    setState(() {
      _leafCoins = (wallet['balance'] as num).toInt();
      _moonlightOwned = packs.contains('moonlight');
      _sakuraOwned = packs.contains('sakura');
      _autumnOwned = packs.contains('golden_autumn');
    });
    final cosmetics = _cloud.currentGarden?['cosmetics'];
    if (cosmetics is Map) {
      setState(() => _shopLoadout = ShopLoadout.fromMap(Map<String, dynamic>.from(cosmetics),
          ownedPacks: _ownedPacks, moonlightOwned: _moonlightOwned, sakuraOwned: _sakuraOwned, autumnOwned: _autumnOwned));
    }
    _save(syncCloud: false);
  }

  Future<void> _openAccount({bool initialChoice = false}) async {
    if (_accountPageOpen) return;
    _accountPageOpen = true;
    try {
      await _loadWork;
      await _saveQueue;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AccountPage(account: _cloud, initialChoice: initialChoice)));
      if (mounted) setState(() {});
    } finally { _accountPageOpen = false; }
  }

  Future<void> _save({bool syncCloud = true}) {
    final cloudSnapshot = syncCloud && _cloud.initialized ? _cloudSnapshot() : null;
    // Capture synchronously before queued disk/native work so a network reply
    // cannot overwrite edits that have not reached SharedPreferences yet.
    final cloudWrite = cloudSnapshot == null ? Future<void>.value() : _cloud.capture(cloudSnapshot);
    final habitSnapshot = _habits.map((habit) => habit.toJson()).toList();
    final habits = jsonEncode(habitSnapshot);
    final progress = jsonEncode(_progress.toJson());
    final day = _today;
    final water = _progress.waterBalance;
    final stage = _progress.treeStage + 1;
    final done = _completed;
    final total = _habits.length;
    final packId = _shopLoadout.packId;
    final ownedMoonlight = _moonlightOwned;
    final ownedSakura = _sakuraOwned;
    final ownedAutumn = _autumnOwned;
    final activeLoadout = _shopLoadout;
    final leafCoins = _leafCoins;
    final deliveredLeafPurchases = _deliveredLeafPurchases.toList()..sort();
    final savedPlacements = jsonEncode({
      for (final entry in _treePlacements.entries) entry.key: entry.value.toJson(),
    });
    // Serialized writes avoid an earlier slow SharedPreferences write
    // overwriting newer completion/water data.
    _saveQueue = _saveQueue.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageHabits, habits);
      await prefs.setString(_storageProgress, progress);
      await prefs.setString(_storageDate, day);
      await prefs.setString(_storageBundle, packId);
      await prefs.setString(_storageTreePlacements, savedPlacements);
      await prefs.setBool(_storageOwnedMoonlight, ownedMoonlight);
      await prefs.setBool(_storageOwnedSakura, ownedSakura);
      await prefs.setBool(_storageOwnedAutumn, ownedAutumn);
      await prefs.setInt(_storageLeafCoins, leafCoins);
      await prefs.setStringList(_storageDeliveredLeafPurchases, deliveredLeafPurchases);
      await prefs.setString(_storageTreeSkin, activeLoadout.treeSkinId);
      await prefs.setString(_storageBackground, activeLoadout.backgroundId);
      await prefs.setString(_storageButterfly, activeLoadout.butterflyId);
      await prefs.setString(_storageWateringCan, activeLoadout.wateringCanId);
      await prefs.setString(_storageFirefly, activeLoadout.fireflyId);
      await cloudWrite;
      await DeviceFeatures.syncHabitReminders(habits: habitSnapshot, day: day);
      await DeviceFeatures.updateWidget(water: water, stage: stage, done: done, total: total, day: day, theme: packId, treeAsset: GardenAppearance(activeLoadout).treeAsset(stage - 1));
    });
    return _saveQueue;
  }

  void _ensureToday() {
    if (!_loaded) return;
    final now = todayLocalKey();
    if (_today == now) return;
    setState(() {
      _today = now;
      _habits = _habits.map((habit) => habit.copyWith(completed: false)).toList();
    });
    _save();
  }

  void _changeTab(int index) {
    if (index == _selectedTab) return;
    _ensureToday();
    setState(() => _selectedTab = index);
    _applyAnimationPreference();
    // Navigation is silent so it cannot interrupt the ambient soundscape.
  }

  void _toggleHabit(Habit habit) {
    if (!_loaded) return;
    _ensureToday();
    final index = _habits.indexWhere((item) => item.id == habit.id);
    if (index < 0) return;
    final done = !_habits[index].completed;
    bool awarded = false;
    setState(() {
      _habits[index] = _habits[index].copyWith(completed: done);
      if (done) awarded = _progress.earnForHabit(_today, habit.id);
    });
    _audio.effect(done ? 'complete' : 'tap');
    if (awarded && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('+1 water earned! Visit Garden to water your tree. 💧'),
        duration: Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ));
    }
    _save();
  }

  Future<void> _waterTree() async {
    if (!_loaded) return;
    _ensureToday();
    if (_progress.waterBalance == 0) {
      _changeTab(1);
      return;
    }
    final oldStage = _progress.treeStage;
    setState(() => _progress.waterTree());
    if (_showAnimation) _waterController.forward(from: 0);
    final newStage = _progress.treeStage;
    _audio.effect(newStage > oldStage ? 'growth' : 'water');
    _save();
    if (newStage > oldStage) {
      if (_showAnimation) {
        await Future<void>.delayed(const Duration(milliseconds: 850));
      }
      if (mounted) await _showStageCelebration(newStage);
    }
  }

  Future<void> _showStageCelebration(int stage) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: SingleChildScrollView(
          child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF24464E), Color(0xFF10252D), Color(0xFF302949)]),
            border: Border.all(color: _gold.withValues(alpha: .75)),
            boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 30)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.auto_awesome_rounded, color: _gold, size: 29),
            const SizedBox(height: 10),
            const Text('Congratulations!',
              textAlign: TextAlign.center,
              style: TextStyle(color: _gold, fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text('Your tree reached Stage ${stage + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            SizedBox(height: 175, child: TweenAnimationBuilder<double>(
              tween: Tween(begin: .72, end: 1),
              duration: _showAnimation ? const Duration(milliseconds: 550) : Duration.zero,
              curve: Curves.easeOutBack,
              builder: (_, value, child) => Transform.scale(
                scale: value, alignment: Alignment.bottomCenter, child: child),
              child: GardenImage.asset(_activeTreeImages[stage], fit: BoxFit.contain),
            )),
            const Text('Every small step helps your garden grow ✨',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFE2EEDC), fontSize: 12)),
            const SizedBox(height: 15),
            SizedBox(width: double.infinity,
              child: FilledButton(
                key: const ValueKey('stage-congratulations-close'),
                style: FilledButton.styleFrom(backgroundColor: _mint,
                  foregroundColor: _deepNavy),
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Continue Growing'),
              ),
            ),
          ]),
        ),
        ),
      ),
    );
  }

  Future<_HabitDraft?> _composeHabit({Habit? initial}) =>
      showModalBottomSheet<_HabitDraft>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: const Color(0xFF102D31),
        builder: (_) => _HabitComposer(
          initial: initial, masterEnabled: _reminderEnabled,
          onEnableMaster: () => _configureReminder(true),
        ),
      );

  Future<void> _addHabit() async {
    final draft = await _composeHabit();
    if (!mounted || draft == null || draft.title.isEmpty) return;
    setState(() => _habits.add(Habit(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: draft.title,
          iconKey: draft.iconKey,
          reminderEnabled: draft.reminderEnabled,
          reminderHour: draft.hour,
          reminderMinute: draft.minute,
        )));
    _audio.effect('plant');
    _save();
  }

  Future<void> _editHabit(Habit habit) async {
    final draft = await _composeHabit(initial: habit);
    if (!mounted || draft == null || draft.title.isEmpty) return;
    final index = _habits.indexWhere((item) => item.id == habit.id);
    if (index < 0) return;
    setState(() => _habits[index] = _habits[index].copyWith(
      title: draft.title,
      iconKey: draft.iconKey,
      reminderEnabled: draft.reminderEnabled,
      reminderHour: draft.hour,
      reminderMinute: draft.minute,
    ));
    _save();
  }

  Future<void> _removeHabit(Habit habit) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove habit?'),
        content: Text('Remove “${habit.title}” from your checklist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    setState(() => _habits.removeWhere((item) => item.id == habit.id));
    // Previous water awards/XP are deliberately not deleted or duplicated.
    _save();
  }

  void _openAssetEditor() {
    if (!_loaded) return;
    setState(() {
      _assetEditMode = true;
      _focusMode = false;
      _selectedTab = 0;
      _editLoadout = _shopLoadout;
      _editPlacements = Map<String, GardenTreePlacement>.from(_treePlacements);
      _assetEditorPanel = 'position';
      _editorAdjustment = 'size';
      _editorAssetCategory = 'background';
    });
    _applyAnimationPreference();
  }

  void _editAsset(String field, String value) {
    final current = _editLoadout;
    if (!_assetEditMode || current == null) return;
    setState(() {
      switch (field) {
        case 'tree': _editLoadout = current.copyWith(treeSkinId: value); break;
        case 'background': _editLoadout = current.copyWith(backgroundId: value); break;
        case 'butterfly': _editLoadout = current.copyWith(butterflyId: value); break;
        case 'watering': _editLoadout = current.copyWith(wateringCanId: value); break;
        case 'firefly': _editLoadout = current.copyWith(fireflyId: value); break;
      }
    });
  }

  void _updateTreePlacement(GardenTreePlacement value) {
    if (!_assetEditMode) return;
    setState(() => _editPlacements[_visibleLoadout.backgroundId] = value);
  }

  void _closeAssetEditor({required bool save}) {
    if (!_assetEditMode) return;
    if (save && _editLoadout != null) {
      final locked = _editLoadout!.toJson().values
          .where((id) => !_ownsEditorAsset(id))
          .map((id) => ShopLoadout.assetPackName(id)).toSet().join(', ');
      if (locked.isNotEmpty) {
        showDialog<void>(context: context, builder: (dialog) => AlertDialog(
          title: const Text('Unlock this look'),
          content: Text('Your preview includes $locked assets. Unlock the pack in the Shop, or choose assets you own before saving. Your changes are still here.'),
          actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Keep editing'))],
        ));
        return;
      }
      final missing = <String>{
        for (final entry in _editLoadout!.toJson().entries)
          if (!_packs.installed(GardenPackRegistry.forAsset(entry.key, entry.value).id))
            GardenPackRegistry.forAsset(entry.key, entry.value).name,
      };
      if (missing.isNotEmpty) {
        showDialog<void>(context: context, builder: (dialog) => AlertDialog(
          title: const Text('Download this look'),
          content: Text('Download ${missing.join(', ')} from My Collection before saving this garden look.'),
          actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Keep editing'))],
        ));
        return;
      }
    }
    setState(() {
      if (save && _editLoadout != null) {
        final chosen = _editLoadout!;
        _unavailableCosmetics.clear();
        _shopLoadout = ShopLoadout.fromMap(
          chosen.toJson(),
          ownedPacks: _ownedPacks, moonlightOwned: _moonlightOwned,
          sakuraOwned: _sakuraOwned,
          autumnOwned: _autumnOwned,
        );
        _treePlacements = Map<String, GardenTreePlacement>.from(_editPlacements);
      }
      _assetEditMode = false;
      _editLoadout = null;
      _editPlacements = {};
      _assetEditorPanel = 'position';
      _editorAdjustment = 'size';
      _editorAssetCategory = 'background';
      _selectedTab = save ? 0 : 3;
    });
    if (save) _save();
    _applyAnimationPreference();
  }

  void _applyShopLoadout(ShopLoadout loadout) {
    if (!_ownedPacks.contains(loadout.packId) || !_packs.installed(loadout.packId)) return;
    setState(() { _unavailableCosmetics.clear(); _shopLoadout = loadout; });
    _save();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCoinStore() async {
    if (!_cloud.signedIn || _cloud.needsSignIn) {
      await _openAccount();
      if (!mounted || !_cloud.signedIn || _cloud.needsSignIn) return;
    }
    _billing ??= PlayBilling(_cloud)..start();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BetterSeedCoinStorePage(account: _cloud, billing: _billing!),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _acquirePack(GardenOffer offer) async {
    if(_unlockBusy||!_catalog.online||!_catalog.assetReady(offer.id))return;
    if(!_cloud.signedIn||_cloud.needsSignIn){await _openAccount();return;}
    final yes=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
      title:Text(offer.price==0?'Claim ${offer.name}?':'Unlock ${offer.name}?'),
      content:Text(offer.price==0?'Add this free pack to your account. It stays yours if the price changes later.':'Use ${offer.price} Leaf Coins to unlock this pack for your account?'),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:Text(offer.price==0?'Claim free':'Unlock'))]));
    if(yes!=true||!mounted)return;
    setState(()=>_unlockBusy=true);
    try{await _cloud.unlock(offer.id,offer:offer);_showMessage('Pack added to your collection.');}
    on AccountException catch(e){_showMessage(e.toString());await _catalog.load();}
    finally{if(mounted)setState(()=>_unlockBusy=false);}
  }

  void _setMusic(bool value) {
    setState(() => _musicEnabled = value);
    SharedPreferences.getInstance().then((prefs) => prefs.setBool(_storageMusic, value));
    _save();
    _audio.setMusic(value);
  }

  Future<void> _useDefaultMusic(StateSetter refresh) async {
    if (_musicMode == 'default') return;
    setState(() => _musicMode = 'default');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageMusicMode, 'default');
    await _audio.setCustomMusicPath(null);
    if (mounted && _settingsOpen) refresh(() {});
  }

  Future<void> _useImportedMusic(StateSetter refresh) async {
    final imported = _importedMusic;
    if (imported == null) return;
    setState(() => _musicMode = 'custom');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageMusicMode, 'custom');
    await _audio.setCustomMusicPath(imported.path);
    if (mounted && _settingsOpen) refresh(() {});
  }

  Future<void> _pickLocalMusic(StateSetter refresh) async {
    if (_musicImportBusy) return;
    setState(() => _musicImportBusy = true);
    if (_settingsOpen) refresh(() {});
    try {
      final imported = await LocalMusicFiles.importMp3();
      if (!mounted || imported == null) return;
      setState(() {
        _importedMusic = imported;
        _musicMode = 'custom';
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageMusicMode, 'custom');
      await _audio.setCustomMusicPath(imported.path, forceRestart: true);
      if (mounted) _backupMessage('Selected music: ${imported.name}');
    } on PlatformException catch (e) {
      if (mounted) _backupMessage('MP3 import failed (${e.code}). Your previous music is unchanged.');
    } catch (_) {
      if (mounted) _backupMessage('MP3 could not be imported. Please choose another file.');
    } finally {
      if (mounted) {
        setState(() => _musicImportBusy = false);
        if (_settingsOpen) refresh(() {});
      }
    }
  }

  Future<void> _confirmResetTreeGrowth() async {
    if (_progress.xp == 0) {
      _backupMessage('Your plant is already at the first growth stage.');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Reset plant growth?'),
        content: const Text(
          'This resets only your plant to Stage 1 (0 XP). '
          'Your habits, completed checklists, streaks, water balance, '
          'earned water and spent water will stay unchanged. '
          'Previously spent water is not refunded. This cannot be undone '
          'unless you restore an earlier backup.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-reset-tree'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Reset plant only'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _progress.resetTreeGrowth());
    await _save(); // also refreshes the native home-screen widget stage
    if (mounted) _backupMessage('Plant growth reset. Your habits and water are preserved.');
  }

  void _setEffects(bool value) {
    setState(() => _effectsEnabled = value);
    SharedPreferences.getInstance().then((prefs) => prefs.setBool(_storageSfx, value));
    _save();
    _audio.setEffects(value);
  }

  void _setMotion(bool value) {
    setState(() => _motionEnabled = value);
    _applyAnimationPreference();
    SharedPreferences.getInstance().then((prefs) => prefs.setBool(_storageMotion, value));
    _save();
  }

  void _setMotionOverride(bool value) {
    setState(() => _motionOverride = value);
    _applyAnimationPreference();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_storageMotionOverride, value),
    );
    _save();
  }

  Future<void> _refreshReminderPermission() async {
    final status = await DeviceFeatures.getReminder();
    if (!mounted) return;
    final enabled = status['enabled'] == true && status['permissionGranted'] == true;
    if (enabled != _reminderEnabled) setState(() => _reminderEnabled = enabled);
  }

  Future<bool> _configureReminder(bool enabled) async {
    if (_reminderBusy) return _reminderEnabled;
    setState(() => _reminderBusy = true);
    final result = await DeviceFeatures.setReminder(enabled: enabled);
    if (!mounted) return result;
    setState(() {
      _reminderBusy = false;
      _reminderEnabled = result;
    });
    if (enabled && !result) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Allow notifications in Android Settings to enable reminders.'),
      ));
    }
    // Refresh the native schedule for each opt-in habit on master changes.
    await _save();
    return result;
  }

  Future<void> _installHomeWidget() async {
    final installed = await DeviceFeatures.widgetInstalled();
    if (!mounted) return;
    if (installed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('BetterSeed widget is already on your home screen.'),
      ));
      return;
    }
    final accepted = await DeviceFeatures.requestPinWidget();
    if (!mounted) return;
    if (accepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Confirm the widget placement in your Android launcher.'),
      ));
    } else {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add BetterSeed widget'),
          content: const Text('On your Android home screen, long-press an empty area, choose Widgets, find BetterSeed, then drag the widget onto your screen. Widget availability depends on your launcher.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Got it')),
          ],
        ),
      );
    }
  }

  BackupSnapshot _snapshotForFile() => BackupSnapshot(
        habits: List<Habit>.from(_habits),
        progress: _progress,
        day: _today,
        packId: _shopLoadout.packId,
        ownedMoonlight: _moonlightOwned,
        ownedSakura: _sakuraOwned,
        ownedAutumn: _autumnOwned,
        cosmetics: {..._shopLoadout.toJson(), ..._unavailableCosmetics},
        treePlacements: {for (final e in _treePlacements.entries) e.key: e.value.toJson()},
        savedAtUtc: DateTime.now().toUtc(),
      );

  void _backupMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  Future<void> _backupToDocument() async {
    if (_backupBusy || !_loaded) return;
    setState(() => _backupBusy = true);
    try {
      // First wait for all queued local writes, then snapshot current progress.
      await _saveQueue;
      final snapshot = _snapshotForFile();
      final name = 'BetterSeed-backup-${snapshot.day}.json';
      final saved = await LocalBackupFiles.saveJson(
        suggestedName: name, contents: snapshot.encode(),
      );
      if (saved) {
        _backupMessage('Backup saved. Keep this file somewhere safe.');
      } else {
        _backupMessage('Backup canceled. Your local data is unchanged.');
      }
    } on PlatformException {
      _backupMessage('Unable to save your backup. Try a different folder.');
    } on FormatException {
      _backupMessage('Backup data could not be prepared. Your local progress is safe.');
    } catch (_) {
      _backupMessage('Backup was not saved. Your local progress is safe.');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreFromDocument() async {
    if (_backupBusy || !_loaded) return;
    setState(() => _backupBusy = true);
    try {
      final contents = await LocalBackupFiles.openJson();
      if (contents == null) {
        _backupMessage('Restore canceled. Your local data is unchanged.');
        return;
      }
      // Decode and validate BEFORE any write or state change.
      final backup = BackupSnapshot.decode(contents);
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Restore BetterSeed backup?'),
          content: Text(
            'Saved: ${backup.savedAtUtc.toLocal()}\n'
            'Habits: ${backup.habits.length}\n'
            'XP: ${backup.progress.xp}\n\n'
            'This replaces your checklist, water, XP and selected Garden theme. '
            'A safety copy is saved on this phone first. Notification permission '
            'and the master switch remain device-specific.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Restore backup')),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      await _saveQueue;
      final prefs = await SharedPreferences.getInstance();
      // No local state is changed until the rollback checkpoint is saved.
      final checkpoint = _snapshotForFile().encode();
      if (!await prefs.setString('betterseed_pre_restore_checkpoint_v1_${_cloud.userId ?? 'guest'}', checkpoint)) {
        _backupMessage('Restore canceled: could not save the local safety copy.');
        return;
      }
      final today = todayLocalKey();
      setState(() {
        _habits = backup.day == today
            ? List<Habit>.from(backup.habits)
            : backup.habits.map((h) => h.copyWith(completed: false)).toList();
        _progress = backup.progress;
        _today = today;
        _moonlightOwned = _cloud.signedIn ? (_cloud.wallet?['packs'] as List?)?.contains('moonlight') == true : _moonlightOwned;
        _sakuraOwned = _cloud.signedIn ? (_cloud.wallet?['packs'] as List?)?.contains('sakura') == true : _sakuraOwned;
        _autumnOwned = _cloud.signedIn ? (_cloud.wallet?['packs'] as List?)?.contains('golden_autumn') == true : _autumnOwned;
        _rememberUnavailableCosmetics(backup.cosmetics);
        _shopLoadout = backup.loadoutFor(_ownedPacks);
        _treePlacements = {
          for (final key in backup.treePlacements.keys.take(200))
            if (RegExp(r'^[a-z][a-z0-9_]{0,79}$').hasMatch(key))
              key: GardenTreePlacement.fromJson(backup.treePlacements[key]),
        };
      });
      await _save();
      _backupMessage('Backup restored. Garden and checklist updated.');
    } on FormatException {
      _backupMessage('Invalid or unsupported BetterSeed backup. Your progress is unchanged.');
    } on PlatformException {
      _backupMessage('Unable to open this backup. Your progress is unchanged.');
    } catch (_) {
      _backupMessage('Restore failed. Try Undo last restore if data changed.');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restorePreviousLocal() async {
    if (_backupBusy || !_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final checkpoint = prefs.getString('betterseed_pre_restore_checkpoint_v1_${_cloud.userId ?? 'guest'}');
    if (!mounted) return;
    if (checkpoint == null) {
      _backupMessage('There is no earlier backup to restore.');
      return;
    }
    BackupSnapshot backup;
    try {
      backup = BackupSnapshot.decode(checkpoint);
    } catch (_) {
      _backupMessage('The earlier backup could not be opened.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Undo last restore?'),
        content: Text('Restore ${backup.habits.length} habits and ${backup.progress.xp} XP from the safety copy?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Undo restore')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _saveQueue;
    final today = todayLocalKey();
    setState(() {
      _habits = backup.day == today
          ? List<Habit>.from(backup.habits)
          : backup.habits.map((h) => h.copyWith(completed: false)).toList();
      _progress = backup.progress;
      _today = today;
      _moonlightOwned = _cloud.signedIn ? (_cloud.wallet?['packs'] as List?)?.contains('moonlight') == true : _moonlightOwned;
      _sakuraOwned = _cloud.signedIn ? (_cloud.wallet?['packs'] as List?)?.contains('sakura') == true : _sakuraOwned;
      _autumnOwned = _cloud.signedIn ? (_cloud.wallet?['packs'] as List?)?.contains('golden_autumn') == true : _autumnOwned;
      _rememberUnavailableCosmetics(backup.cosmetics);
      _shopLoadout = backup.loadoutFor(_ownedPacks);
      _treePlacements = {
        for (final key in backup.treePlacements.keys.take(200))
          if (RegExp(r'^[a-z][a-z0-9_]{0,79}$').hasMatch(key))
            key: GardenTreePlacement.fromJson(backup.treePlacements[key]),
      };
    });
    await _save();
    await prefs.remove('betterseed_pre_restore_checkpoint_v1_${_cloud.userId ?? 'guest'}');
    _backupMessage('Your previous local progress has been restored.');
  }

  void _openWallpaper() {
    if (!_loaded || _assetEditMode) return;
    final stage = _progress.treeStage;
    final media = MediaQuery.of(context);
    final assets = <String>[
      _activeBackgroundAsset, _activeTreeImages[stage],
      if (_showAnimation) _activeButterflyAsset,
    ];
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GardenWallpaperPage(
        viewport: media.size,
        mediaQuery: media,
        assets: assets,
        garden: Stack(
          fit: StackFit.expand,
          children: [
            _buildGardenBackdrop(still: true),
            _buildGardenLayout(stage, preview: true, still: true),
          ],
        ),
      ),
    ));
  }

  Future<void> _openSettings() async {
    _settingsOpen = true;
    var section = _SettingsSection.home;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF102D31),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .72,
          minChildSize: .46,
          maxChildSize: .92,
          builder: (sheetContext, scrollController) => SafeArea(
            top: false,
            child: SingleChildScrollView(
              key: const ValueKey('settings-scroll'),
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 3, 20, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _settingsPageChildren(
                    section: section,
                    refresh: refresh,
                    openSection: (next) {
                      refresh(() => section = next);
                      // Keep the header and back button visible after a
                      // category switch, even if the previous page scrolled.
                      if (scrollController.hasClients) {
                        scrollController.jumpTo(0);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _settingsOpen = false;
  }

  List<Widget> _settingsPageChildren({
    required _SettingsSection section,
    required StateSetter refresh,
    required void Function(_SettingsSection next) openSection,
  }) {
    switch (section) {
      case _SettingsSection.soundGarden:
        return _buildSoundGardenSettings(refresh, () => openSection(_SettingsSection.home));
      case _SettingsSection.routine:
        return _buildRoutineSettings(refresh, () => openSection(_SettingsSection.home));
      case _SettingsSection.gardenProgress:
        return _buildGardenProgressSettings(() => openSection(_SettingsSection.home));
      case _SettingsSection.widgetDisplay:
        return _buildWidgetDisplaySettings(refresh, () => openSection(_SettingsSection.home));
      case _SettingsSection.backupRestore:
        return _buildBackupSettings(refresh, () => openSection(_SettingsSection.home));
      case _SettingsSection.home:
        return _buildSettingsHome(openSection);
    }
  }

  List<Widget> _buildSettingsHome(void Function(_SettingsSection next) openSection) => [
        _settingsPageHeader(
          title: 'Settings',
          subtitle: 'Make BetterSeed feel right for you.',
        ),
        const SizedBox(height: 16),
        _settingsCategoryTile(
          key: const ValueKey('settings-menu-sound'),
          icon: Icons.tune_rounded,
          title: 'Sound & Garden',
          subtitle: 'Music, sound effects and living garden motion',
          trailingLabel: _motionEnabled ? 'Motion on' : 'Motion off',
          onTap: () => openSection(_SettingsSection.soundGarden),
        ),
        const SizedBox(height: 10),
        _settingsCategoryTile(
          key: const ValueKey('settings-menu-routine'),
          icon: Icons.notifications_active_outlined,
          title: 'Daily Routine',
          subtitle: 'Habit reminders and notification controls',
          trailingLabel: _reminderEnabled ? 'Enabled' : 'Off',
          onTap: () => openSection(_SettingsSection.routine),
        ),
        const SizedBox(height: 10),
        _settingsCategoryTile(
          key: const ValueKey('settings-menu-growth'),
          icon: Icons.spa_outlined,
          title: 'Garden Progress',
          subtitle: 'Restart plant growth without changing any habits',
          trailingLabel: 'Manage',
          onTap: () => openSection(_SettingsSection.gardenProgress),
        ),
        const SizedBox(height: 10),
        _settingsCategoryTile(
          key: const ValueKey('settings-menu-widget'),
          icon: Icons.widgets_outlined,
          title: 'Widget & Display',
          subtitle: 'Garden wallpaper, home widget and focus mode',
          trailingLabel: 'Open',
          onTap: () => openSection(_SettingsSection.widgetDisplay),
        ),
        const SizedBox(height: 10),
        _settingsCategoryTile(
          key: const ValueKey('settings-menu-backup'),
          icon: Icons.backup_outlined,
          title: 'Backup & Restore',
          subtitle: 'Android backup plus manual backup file tools',
          trailingLabel: 'Manage',
          onTap: () => openSection(_SettingsSection.backupRestore),
        ),
        const SizedBox(height: 10),
        _settingsCategoryTile(
          key: const ValueKey('settings-menu-account'), icon: Icons.account_circle_outlined,
          title: 'Account & sync', subtitle: _cloud.signedIn ? _cloud.status : 'Sign in to keep your garden across devices',
          trailingLabel: _cloud.signedIn ? 'Manage' : 'Sign in',
          onTap: () { Navigator.of(context).pop(); _openAccount(); },
        ),
        const SizedBox(height: 10),
        _settingsCategoryTile(
          key: const ValueKey('settings-menu-legal'), icon: Icons.info_outline,
          title: 'Help & information', subtitle: 'Common questions, privacy and app information', trailingLabel: 'Read',
          onTap: () { Navigator.of(context).pop(); Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LegalPage(api: _cloud.api))); },
        ),
        const SizedBox(height: 18),
        _glassPanel(
          padding: const EdgeInsets.all(14),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: _gold),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your garden, your pace. Adjust your preferences whenever you need.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFD4E2DC)),
                ),
              ),
            ],
          ),
        ),
      ];

  List<Widget> _buildSoundGardenSettings(StateSetter refresh, VoidCallback onBack) => [
        _settingsPageHeader(
          title: 'Sound & Garden',
          subtitle: 'Tune the mood of your garden.',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        _settingsSectionCard(
          title: 'AMBIENCE',
          children: [
            SwitchListTile.adaptive(
              title: const Text('Background music'),
              subtitle: const Text('Play selected soundtrack while the app is open'),
              secondary: const Icon(Icons.music_note_rounded, color: _gold),
              value: _musicEnabled,
              onChanged: (v) {
                _setMusic(v);
                refresh(() {});
              },
            ),
            SwitchListTile.adaptive(
              title: const Text('Gentle sound effects'),
              subtitle: const Text('Checklist and watering sounds'),
              secondary: const Icon(Icons.graphic_eq_rounded, color: _gold),
              value: _effectsEnabled,
              onChanged: (v) {
                _setEffects(v);
                refresh(() {});
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _settingsSectionCard(
          title: 'BACKGROUND MUSIC SOURCE',
          children: [
            ListTile(
              key: const ValueKey('music-source-default'),
              leading: Icon(_musicMode == 'default'
                  ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _mint),
              title: const Text('Default forest piano'),
              subtitle: const Text('Built-in offline soundtrack'),
              onTap: () => _useDefaultMusic(refresh),
            ),
            ListTile(
              key: const ValueKey('music-source-custom'),
              leading: Icon(_musicMode == 'custom'
                  ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _importedMusic == null ? Colors.white38 : _mint),
              title: const Text('My MP3'),
              subtitle: Text(_importedMusic?.name ?? 'Choose a local MP3 first'),
              onTap: _importedMusic == null
                  ? null : () => _useImportedMusic(refresh),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 12, 8),
              child: OutlinedButton.icon(
                key: const ValueKey('music-import-mp3'),
                onPressed: _musicImportBusy ? null : () => _pickLocalMusic(refresh),
                icon: const Icon(Icons.library_music_outlined),
                label: Text(_musicImportBusy ? 'Importing...' : 'Choose MP3 from device'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('MP3 only • up to 25 MB • stays offline in private app storage. '
                'Switch back to the default music any time. '
                'Your music stays on this phone and is not included in backups.',
                style: TextStyle(fontSize: 11, color: Color(0xFFCEDFD7))),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _settingsSectionCard(
          title: 'GARDEN MOTION',
          children: [
            SwitchListTile.adaptive(
              title: const Text('Living garden'),
              subtitle: const Text('Continuous butterflies and fireflies'),
              secondary: const Icon(Icons.auto_awesome, color: _mint),
              value: _motionEnabled,
              onChanged: (v) {
                _setMotion(v);
                refresh(() {});
              },
            ),
            SwitchListTile.adaptive(
              key: const ValueKey('garden-motion-override'),
              title: const Text('Keep Garden effects animated'),
              subtitle: const Text(
                'Explicitly play garden effects even when device animations are disabled',
              ),
              secondary: const Icon(Icons.auto_awesome_outlined, color: _mint),
              value: _motionOverride,
              onChanged: _motionEnabled
                  ? (v) {
                      _setMotionOverride(v);
                      refresh(() {});
                    }
                  : null,
            ),
            if (_systemReduceMotion)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Text(
                  _motionOverride
                      ? 'Garden effects are enabled by your choice. You can switch them off anytime.'
                      : 'Android currently requests reduced motion. Enable the option above if you want Garden effects anyway.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFCEDFD7)),
                ),
              ),
          ],
        ),
      ];

  List<Widget> _buildGardenProgressSettings(VoidCallback onBack) => [
        _settingsPageHeader(
          title: 'Garden Progress',
          subtitle: 'Your plant grows independently from your habits.',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        _settingsSectionCard(
          title: 'PLANT GROWTH',
          children: [
            ListTile(
              leading: const Icon(Icons.spa_outlined, color: _mint),
              title: Text('Stage ${_progress.treeStage + 1} of 6'),
              subtitle: Text('${_progress.xp} XP • ${_progress.waterBalance} water available'),
            ),
            ListTile(
              key: const ValueKey('settings-reset-tree'),
              leading: const Icon(Icons.restart_alt_rounded, color: _gold),
              title: const Text('Reset plant growth'),
              subtitle: const Text('Start your tree at Stage 1 without resetting habits, streaks or water'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _confirmResetTreeGrowth,
            ),
          ],
        ),
      ];

  List<Widget> _buildRoutineSettings(StateSetter refresh, VoidCallback onBack) => [
        _settingsPageHeader(
          title: 'Daily Routine',
          subtitle: 'Reminders and day-to-day habit flow.',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        _settingsSectionCard(
          title: 'REMINDERS',
          children: [
            SwitchListTile.adaptive(
              key: const ValueKey('reminder-toggle'),
              secondary: const Icon(Icons.notifications_active_outlined, color: _mint),
              title: const Text('Notifications master switch'),
              subtitle: const Text('Enable or pause reminders for all habits'),
              value: _reminderEnabled,
              onChanged: _reminderBusy
                  ? null
                  : (value) async {
                      await _configureReminder(value);
                      if (mounted) refresh(() {});
                    },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 2, 12, 14),
              child: Text(
                'Choose a reminder time separately when you add or edit each habit. Only habits with reminders enabled will notify you.',
                style: TextStyle(color: Color(0xFFBCD1C8), fontSize: 12),
              ),
            ),
          ],
        ),
      ];

  List<Widget> _buildWidgetDisplaySettings(StateSetter refresh, VoidCallback onBack) => [
        _settingsPageHeader(
          title: 'Widget & Display',
          subtitle: 'Shortcut access and a cleaner full-screen garden.',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        _settingsSectionCard(
          title: 'HOME SCREEN',
          children: [
            ListTile(
              key: const ValueKey('widget-add'),
              leading: const Icon(Icons.widgets_outlined, color: _mint),
              title: const Text('Home screen widget'),
              subtitle: const Text('See tree stage, water and checklist at a glance'),
              trailing: const Icon(Icons.add_circle_outline_rounded, color: _mint),
              onTap: _installHomeWidget,
            ),
            ListTile(
              key: const ValueKey('settings-garden-wallpaper'),
              leading: const Icon(Icons.wallpaper_outlined, color: _mint),
              title: const Text('Garden wallpaper'),
              subtitle: const Text('Set your current garden on your home or lock screen'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).pop();
                _openWallpaper();
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _settingsSectionCard(
          title: 'DISPLAY NOTES',
          children: [
            const ListTile(
              leading: Icon(Icons.fullscreen_rounded, color: _gold),
              title: Text('Focus mode'),
              subtitle: Text('Enjoy your garden full-screen. Tap the exit button to return.'),
            ),
            if (widget.onShowWelcomeGuide != null)
              ListTile(
                key: const ValueKey('settings-replay-onboarding'),
                leading: const Icon(Icons.auto_stories_outlined, color: _mint),
                title: const Text('Welcome guide'),
                subtitle: const Text('Replay the introduction and headphone tips'),
                trailing: const Icon(Icons.chevron_right_rounded, color: _mint),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onShowWelcomeGuide?.call();
                },
              ),
          ],
        ),
      ];

  List<Widget> _buildBackupSettings(StateSetter refresh, VoidCallback onBack) => [
        _settingsPageHeader(
          title: 'Backup & Restore',
          subtitle: 'Keep your progress safe without a login.',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        _settingsSectionCard(
          title: 'ANDROID BACKUP',
          children: const [
            ListTile(
              key: ValueKey('backup-auto-info'),
              leading: Icon(Icons.cloud_done_outlined, color: _mint),
              title: Text('Android Auto Backup'),
              subtitle: Text(
                'Android can include your progress in your phone backup when device backup is enabled. Sign in to BetterSeed to keep your garden updated across devices.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _settingsSectionCard(
          title: 'MANUAL FILE BACKUP',
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Text(
                'Save a backup file to your phone or Google Drive, if available. You can restore it later without signing in.',
                style: TextStyle(color: Color(0xFFBCD1C8), fontSize: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('saf-backup-now'),
                    onPressed: _backupBusy
                        ? null
                        : () async {
                            await _backupToDocument();
                            if (mounted) refresh(() {});
                          },
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Backup to file'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('saf-restore'),
                    onPressed: _backupBusy
                        ? null
                        : () async {
                            await _restoreFromDocument();
                            if (mounted) refresh(() {});
                          },
                    icon: const Icon(Icons.settings_backup_restore_rounded),
                    label: const Text('Restore from file'),
                  ),
                ],
              ),
            ),
            if (_backupBusy) const LinearProgressIndicator(),
            TextButton.icon(
              key: const ValueKey('backup-undo-local'),
              onPressed: _backupBusy
                  ? null
                  : () async {
                      await _restorePreviousLocal();
                      if (mounted) refresh(() {});
                    },
              icon: const Icon(Icons.undo_rounded, color: _gold),
              label: const Text('Undo last manual restore (if available)'),
            ),
          ],
        ),
      ];

  Widget _settingsPageHeader({
    required String title,
    required String subtitle,
    VoidCallback? onBack,
  }) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                key: const ValueKey('settings-back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: _mint),
                tooltip: 'Back',
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 10, top: 2),
              child: Icon(Icons.settings_rounded, color: _mint, size: 26),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFFCDDED5), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _settingsCategoryTile({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailingLabel,
    required VoidCallback onTap,
  }) => Material(
        key: key,
        color: const Color(0xA5183A3F),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF183E42),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: _mint),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFD0E1DA))),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      trailingLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _mint,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFD0E1DA)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _settingsSectionCard({
    required String title,
    required List<Widget> children,
  }) => Material(
        // ListTile and SwitchListTile paint ink on their nearest Material.
        // A colored DecoratedBox between them and Material obscures the ink
        // and is rejected by Flutter's widget tests. Paint the card using
        // Material itself instead of the generic glass Container.
        color: _glass,
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        shadowColor: const Color(0x44000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x777AC5A4)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                child: Text(
                  title,
                  style: const TextStyle(color: _mint, fontWeight: FontWeight.w800),
                ),
              ),
              ...children,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final stage = _progress.treeStage;
    return PopScope(
      canPop: !_focusMode && !_assetEditMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_assetEditMode) {
          _closeAssetEditor(save: false);
        } else if (_focusMode) {
          _setFocusMode(false);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: LayoutBuilder(
          builder: (context, constraints) => _assetEditMode
              ? _buildAssetEditor(stage, constraints.biggest)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildGardenBackdrop(),
                    if (_focusMode)
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) => Stack(
                            children: [
                              Positioned.fill(
                                top: constraints.maxHeight * .16,
                                bottom: constraints.maxHeight * .18,
                                child: _buildTreeScene(stage),
                              ),
                              SafeArea(
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Material(
                                      color: const Color(0xDC09272C),
                                      borderRadius: BorderRadius.circular(18),
                                      child: IconButton(
                                        key: const ValueKey('exit-focus-mode'),
                                        tooltip: 'Exit focus mode',
                                        onPressed: () => _setFocusMode(false),
                                        icon: const Icon(
                                          Icons.fullscreen_exit_rounded,
                                          color: _mint,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      _buildGardenLayout(stage),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGardenBackdrop({bool still = false}) => Stack(
    fit: StackFit.expand,
    children: [
      if (!still && _appearance.video != null)
        LocalPackVideoBackground(
          key: ValueKey(_appearance.video),
          animate: _showAnimation && (_selectedTab == 0 || _focusMode),
          video: _appearance.video!, poster: _activeBackgroundAsset)
      else
        AdaptiveGardenBackground(asset: _activeBackgroundAsset),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .20, .75, 1],
            colors: [
              Color(0x85071820),
              Color(0x26071921),
              Color(0x00071921),
              Color(0x7003151A),
            ],
          ),
        ),
      ),
      if (_loaded &&
          _showAnimation &&
          _visibleLoadout.backgroundId == 'twilight_overlook')
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _windController,
              builder: (_, __) => RepaintBoundary(
                child: CustomPaint(
                  key: const ValueKey('moonlight-dynamic-background'),
                  painter: MoonlightAmbiencePainter(still ? .3 : _windController.value),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  // Keep the same layout and safe-area insets in the editor. Hiding chrome
  // must not change the scene's size, origin, or background crop.
  Widget _previewChrome(Widget child, {required bool preview}) => IgnorePointer(
    ignoring: preview,
    child: ExcludeFocus(
      excluding: preview,
      child: ExcludeSemantics(
        excluding: preview,
        child: Opacity(opacity: preview ? 0 : 1, child: child),
      ),
    ),
  );

  Widget _buildGardenLayout(int stage, {bool preview = false, bool still = false}) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            _previewChrome(_buildHeader(), preview: preview),
            Expanded(
              child: preview
                  ? _buildGarden(stage, preview: true, still: still)
                  : _loaded
                  ? IndexedStack(
                      index: _selectedTab,
                      sizing: StackFit.expand,
                      children: [
                        _buildGarden(stage),
                        _buildChecklist(),
                        _buildStats(),
                        BetterSeedShopPage(
                          loadout: _shopLoadout,
                          onApplyLoadout: _applyShopLoadout,
                          ownedPacks: _ownedPacks, moonlightOwned: _moonlightOwned,
                          sakuraOwned: _sakuraOwned,
                          autumnOwned: _autumnOwned,
                          leafCoins: _leafCoins,
                          catalog: _catalog,
                          downloads: _packs,
                          onAcquire: _acquirePack,
                          acquiring: _unlockBusy,
                          onEditAssets: _openAssetEditor,
                          onOpenCoinStore: _openCoinStore,
                          currentStage: stage,
                          animatePreviews: _showAnimation,
                        ),
                      ],
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: _mint),
                    ),
            ),
            _previewChrome(_buildNavigation(), preview: preview),
          ],
        ),
      ),
    ),
  );

  Widget _glassPanel({required Widget child, EdgeInsetsGeometry? padding}) => Container(
        padding: padding ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _glass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x777AC5A4)),
          boxShadow: const [
            BoxShadow(color: Color(0x44000000), blurRadius: 18, offset: Offset(0, 5)),
          ],
        ),
        child: child,
      );

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          GardenImage.asset('assets/icon_512.png', height: 36, width: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BetterSeed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                Text('Grow one step at a time',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Color(0xFFCFDED6))),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: '${_leafCoins} leaf coins available',
            child: InkWell(
              key: const ValueKey('open-coin-store-header'),
              onTap: _openCoinStore,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xD10B3033),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x779EF7BD)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.spa_rounded, size: 18, color: _mint),
                    const SizedBox(width: 4),
                    Text('${_leafCoins}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_rounded, color: _mint, size: 23),
          ),
        ],
      ),
    );
  }

  // The nav bar has four tabs. Its height must account for the current text
  // scaling factor; a fixed 64px bar could overflow by a few pixels on short
  // screens (and more when Android accessibility text is enlarged).
  Widget _buildNavigation() {
    final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(11) * 1.45;
    final contentHeight = 22.0 + 3.0 + scaledLabelHeight + 3.0 + 2.0;
    final navHeight = math.max(72.0, contentHeight + 16.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 8),
      child: Container(
        height: navHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xEE092529),
          border: Border.all(color: const Color(0x9874AD96)),
        ),
        child: Row(
          children: [
            _navItem(0, Icons.spa_rounded, 'Garden'),
            _navItem(1, Icons.fact_check_outlined, 'Checklist'),
            _navItem(2, Icons.bar_chart_rounded, 'Stats'),
            _navItem(3, Icons.storefront_outlined, 'Shop'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final active = index == _selectedTab;
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        label: '$label tab',
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          key: ValueKey('tab-$index'),
          onTap: () => _changeTab(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? _mint : const Color(0xFFBDCCC8), size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? _mint : const Color(0xFFCFDEDA),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 28, height: 2,
                decoration: BoxDecoration(
                  color: active ? _mint : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGarden(int stage, {bool preview = false, bool still = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _previewChrome(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.park_outlined, size: 18, color: _mint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _stageNames[stage],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      'Stage ${stage + 1} / 6',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE4F5E9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progressToNextStage(_progress.xp),
                    minHeight: 5,
                    color: _mint,
                    backgroundColor: const Color(0x80617E73),
                  ),
                ),
              ],
            ),
          ),
          preview: preview,
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _buildTreeScene(stage, clean: preview, still: still)),
              if (!preview)
                Positioned(
                  right: 12,
                  top: 8,
                  child: Material(
                    color: const Color(0xBC0A2B30),
                    borderRadius: BorderRadius.circular(15),
                    child: IconButton(
                      key: const ValueKey('enter-focus-mode'),
                      tooltip: 'Focus mode',
                      onPressed: () => _setFocusMode(true),
                      icon: const Icon(
                        Icons.fullscreen_rounded,
                        color: _mint,
                        size: 25,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _previewChrome(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 1, 12, 8),
            child: _glassPanel(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.water_drop_rounded, color: _blue, size: 27),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_progress.waterBalance} water available',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _progress.waterBalance == 0
                              ? 'Complete a habit to earn water'
                              : 'Give your tree a drink to help it grow',
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFD1E1DA),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    key: const ValueKey('water-tree'),
                    onPressed: _waterTree,
                    icon: Icon(
                      _progress.waterBalance > 0
                          ? Icons.water_drop_outlined
                          : Icons.fact_check_outlined,
                      size: 18,
                    ),
                    label: Text(_progress.waterBalance > 0 ? 'Water' : 'Earn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _mint,
                      foregroundColor: _deepNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      minimumSize: const Size(84, 44),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          preview: preview,
        ),
      ],
    );
  }

  Widget _buildTreeScene(int stage, {bool clean = false, bool still = false}) => LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final baseSize = GardenSceneGeometry.treeSize(Size(w, h));
      // Sakura sprites need a dedicated visual calibration so the root mound
      // sits inside the circular soil patch instead of reading too low.
      final placement = _visiblePlacement;
      final groundWidth = math.min(w * .70, baseSize * .82);
      final scene = Size(w, h);
      final treeRect = GardenSceneGeometry.treeRect(
        scene,
        ground: _activePlantingGround,
        placement: placement,
      );
      final size = treeRect.width;
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Sakura and Golden Autumn already contain a visible planting zone;
          // an extra blurred contact oval would look like a dark stain.
          if (_activePlantingGround == PlantingGround.defaultGarden ||
              _activePlantingGround == PlantingGround.moonlightGarden)
            Positioned(
              bottom:
                  GardenSceneGeometry.plantingPlaneBottom(
                    scene,
                    ground: _activePlantingGround,
                  ) -
                  placement.dy * h,
              left: (w - groundWidth) / 2 + placement.dx * w,
              width: groundWidth,
              height: GardenSceneGeometry.plantingPlaneHeight(scene),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _GroundContactPainter(
                    // Theme palettes change without altering the root anchor.
                    moonlight:
                        _visibleLoadout.backgroundId == 'twilight_overlook',
                  ),
                ),
              ),
            ),
          Positioned.fromRect(
            rect: treeRect,
            child: GestureDetector(
              key: const ValueKey('editor-draggable-tree'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: _assetEditMode && _assetEditorPanel == 'position'
                  ? (details) {
                      _updateTreePlacement(
                        _visiblePlacement.copyWith(
                          dx: _visiblePlacement.dx + details.delta.dx / w,
                          dy: _visiblePlacement.dy + details.delta.dy / h,
                        ),
                      );
                    }
                  : null,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _windController,
                  builder: (context, child) {
                    if (!_showAnimation || _assetEditMode || still) return child!;
                    final sway = math.sin(_windController.value * math.pi * 2);
                    return Transform.rotate(
                      angle: sway * .005,
                      alignment: Alignment.bottomCenter,
                      child: child,
                    );
                  },
                  child: AnimatedSwitcher(
                    duration: _showAnimation && !_assetEditMode && !still
                        ? const Duration(milliseconds: 700)
                        : Duration.zero,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.bottomCenter,
                      children: [...previous, if (current != null) current],
                    ),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        alignment: Alignment.bottomCenter,
                        scale: Tween<double>(begin: .83, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: child,
                      ),
                    ),
                    child: GardenImage.asset(
                      _activeTreeImages[stage],
                      key: ValueKey('${_visibleLoadout.treeSkinId}-$stage'),
                      width: size,
                      height: size,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showAnimation)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _windController,
                  builder: (_, __) => RepaintBoundary(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          key: const ValueKey('garden-live-ambient'),
                          painter: GardenLifePainter(
                            still ? .3 : _windController.value,
                            palette: _activeFireflyPalette,
                          ),
                        ),
                        ...(still
                            ? _buildStillButterflySprites(w, h)
                            : _buildButterflySprites(
                                w,
                                h,
                                _windController.value,
                              )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_showAnimation && !still)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _waterController,
                  builder: (_, __) => Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        key: const ValueKey('garden-watering-stream'),
                        painter: _WateringPainter(
                          _waterController.value,
                          _activePlantingGround,
                          placement,
                          _appearance.spout,
                        ),
                      ),
                      ..._buildWateringCanOverlay(w, h, _waterController.value),
                    ],
                  ),
                ),
              ),
            ),
          if (_assetEditMode && _assetEditorPanel == 'position')
            Positioned.fromRect(
              rect: treeRect,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('editor-tree-selection'),
                  decoration: BoxDecoration(
                    border: Border.all(color: _mint.withValues(alpha: .7)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (!clean && !_assetEditMode && h > 260)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Text(
                _gardenMessage,
                key: const ValueKey('garden-message'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFF0FBEA),
                  fontSize: 11,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _buildAssetEditor(int stage, Size viewport) => GardenEditorFrame(
    viewport: viewport,
    mediaQuery: MediaQuery.of(context),
    preview: Stack(
      fit: StackFit.expand,
      children: [
        _buildGardenBackdrop(),
        _buildGardenLayout(stage, preview: true),
      ],
    ),
    tool: _assetEditorPanel,
    onToolChanged: (tool) => setState(() => _assetEditorPanel = tool),
    controls: _assetEditorPanel == 'assets'
        ? _buildEditorAssetsPanel()
        : _buildEditorPositionPanel(),
    onCancel: () => _closeAssetEditor(save: false),
    onSave: () => _closeAssetEditor(save: true),
  );

  Widget _buildEditorPositionPanel() {
    final placement = _visiblePlacement;
    final isSize = _editorAdjustment == 'size';
    final horizontal = _editorAdjustment == 'x';
    final value = isSize
        ? placement.scale
        : horizontal
        ? placement.dx
        : placement.dy;
    final label = isSize
        ? 'Size'
        : horizontal
        ? 'Horizontal'
        : 'Vertical';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in const [
                ('size', 'Size'),
                ('x', 'Horizontal'),
                ('y', 'Vertical'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('editor-adjust-${item.$1}'),
                    label: Text(item.$2),
                    selected: _editorAdjustment == item.$1,
                    onSelected: (_) =>
                        setState(() => _editorAdjustment = item.$1),
                  ),
                ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              isSize
                  ? '${(value * 100).round()}%'
                  : '${value > 0 ? '+' : ''}${(value * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          key: ValueKey(
            isSize
                ? 'asset-tree-size'
                : horizontal
                ? 'asset-tree-x'
                : 'asset-tree-y',
          ),
          value: value,
          min: isSize ? .65 : -.35,
          max: isSize ? 1.35 : .35,
          semanticFormatterCallback: (v) =>
              '$label ${(v * 100).round()} percent',
          onChanged: (v) => _updateTreePlacement(
            isSize
                ? placement.copyWith(scale: v)
                : horizontal
                ? placement.copyWith(dx: v)
                : placement.copyWith(dy: v),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('asset-editor-reset'),
            onPressed: () => _updateTreePlacement(const GardenTreePlacement()),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset position & size'),
          ),
        ),
      ],
    );
  }

  bool _ownsEditorAsset(String id) => GardenPackRegistry.packs.any((p)=>_ownedPacks.contains(p.id)&&p.loadout.toJson().values.contains(id));

  Widget _buildEditorAssetsPanel() {
    final field = _editorAssetCategory;
    final (current, selectorKey) = switch (field) {
      'tree' => (_visibleLoadout.treeSkinId, 'asset-tree-choice'),
      'butterfly' => (_visibleLoadout.butterflyId, 'asset-butterfly-choice'),
      'watering' => (_visibleLoadout.wateringCanId, 'asset-watering-choice'),
      'firefly' => (_visibleLoadout.fireflyId, 'asset-firefly-choice'),
      _ => (_visibleLoadout.backgroundId, 'asset-background-choice'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in const [
                ('background', 'Background'),
                ('tree', 'Tree'),
                ('butterfly', 'Butterflies'),
                ('watering', 'Watering can'),
                ('firefly', 'Fireflies'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('editor-category-${item.$1}'),
                    label: Text(item.$2),
                    selected: field == item.$1,
                    onSelected: (_) =>
                        setState(() => _editorAssetCategory = item.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          key: ValueKey(selectorKey),
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final choice in _editorChoicesFor(field))
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Semantics(
                    selected: choice.id == current,
                    button: true,
                    label:
                        '${choice.label} ${field == 'watering' ? 'watering can' : field}${_ownsEditorAsset(choice.id) ? '' : ', locked, tap to preview'}',
                    child: SizedBox(
                      width: 84,
                      child: InkWell(
                        key: ValueKey('editor-choice-$field-${choice.id}'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _editAsset(field, choice.id),
                        child: Column(
                          children: [
                            Container(
                              height: 64,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: choice.id == current
                                      ? _mint
                                      : Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildEditorChoiceArtwork(
                                      field,
                                      choice,
                                    ),
                                  ),
                                  if (!_ownsEditorAsset(choice.id))
                                    Align(alignment: Alignment.bottomLeft,
                                      child: Container(
                                        key: ValueKey('editor-lock-${choice.id}'),
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                                        child: const Icon(Icons.lock_rounded, color: Colors.white, size: 14),
                                      )),
                                  if (choice.id == current)
                                    const Align(
                                      alignment: Alignment.topRight,
                                      child: Icon(
                                        Icons.check_circle,
                                        color: _mint,
                                        size: 20,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(choice.label, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditorChoiceArtwork(String field, _EditorAssetChoice choice) {
    switch (field) {
      case 'firefly':
        return _buildFireflyChoiceArtwork(choice.id);
      case 'tree':
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF081A2B), Color(0xFF153A3D)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: GardenImage.asset(choice.assetPath!, fit: BoxFit.contain),
          ),
        );
      case 'butterfly':
      case 'watering':
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF101A33), Color(0xFF261A33)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: GardenImage.asset(choice.assetPath!, fit: BoxFit.contain),
          ),
        );
      default:
        return GardenImage.asset(choice.assetPath!, fit: BoxFit.cover);
    }
  }

  Widget _buildFireflyChoiceArtwork(String id) {
    final palette = GardenPackRegistry.forAsset('fireflyId', id).fireflies;
    final dots = [palette.glow, palette.spark, palette.core];
    final background = [const Color(0xFF101A18), palette.glow.withValues(alpha: .2)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: background,
        ),
      ),
      child: Stack(
        children: [
          for (final dot in [
            const Offset(.24, .35),
            const Offset(.53, .24),
            const Offset(.71, .58),
            const Offset(.39, .67),
            const Offset(.61, .43),
          ])
            Align(
              alignment: Alignment(dot.dx * 2 - 1, dot.dy * 2 - 1),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dots[(dot.dx * 10).toInt() % dots.length].withValues(alpha: .85),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                  color: dots[(dot.dy * 10).toInt() % dots.length],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_EditorAssetChoice> _editorChoicesFor(String field) => [
    // Display every pack in the editor, including locked/uninstalled ones.
    // Non-default full-res sprites live on the CDN: use the bundled Shop
    // thumbnail until a pack is installed rather than loading a missing asset.
    for (final pack in GardenPackRegistry.packs)
      _EditorAssetChoice(
        id: switch (field) {
          'tree' => pack.loadout.treeSkinId,
          'butterfly' => pack.loadout.butterflyId,
          'watering' => pack.loadout.wateringCanId,
          'firefly' => pack.loadout.fireflyId,
          _ => pack.loadout.backgroundId,
        },
        label: pack.id == 'default' ? 'Default' : pack.name,
        assetPath: !_packs.installed(pack.id)
            ? pack.thumbnail
            : switch (field) {
                'tree' => pack.trees.last,
                'butterfly' => pack.butterfly,
                'watering' => pack.wateringCan,
                'firefly' => null,
                _ => pack.background,
              },
      ),
  ];

  List<Widget> _buildButterflySprites(double width, double height, double t) {
    final animated = GardenSceneGeometry.animatedButterflies();
    return [
      for (var i = 0; i < animated.length; i++)
        _butterflySprite(
          key: ValueKey('garden-butterfly-$i'),
          width: width,
          height: height,
          progress: t,
          anchorX: animated[i].anchorX,
          anchorY: animated[i].anchorY,
          size: animated[i].size,
          orbitX: animated[i].orbitX,
          orbitY: animated[i].orbitY,
          phase: animated[i].phase,
          flip: animated[i].flip,
        ),
    ];
  }

  List<Widget> _buildStillButterflySprites(double width, double height) {
    final staticLayout = GardenSceneGeometry.stillButterflies(
      _visibleLoadout.butterflyId,
    );
    return [
      for (var i = 0; i < staticLayout.length; i++)
        _butterflySprite(
          key: ValueKey('garden-butterfly-still-$i'),
          width: width,
          height: height,
          progress: .22,
          anchorX: staticLayout[i].anchorX,
          anchorY: staticLayout[i].anchorY,
          size: staticLayout[i].size,
          orbitX: staticLayout[i].orbitX,
          orbitY: staticLayout[i].orbitY,
          phase: staticLayout[i].phase,
          flip: staticLayout[i].flip,
        ),
    ];
  }

  Widget _butterflySprite({
    Key? key,
    required double width,
    required double height,
    required double progress,
    required double anchorX,
    required double anchorY,
    required double size,
    required double orbitX,
    required double orbitY,
    required double phase,
    required bool flip,
  }) {
    const tau = math.pi * 2;
    final x = width * anchorX + math.sin(tau * progress + phase) * orbitX;
    final y = height * anchorY + math.sin(tau * progress * 2 + phase) * orbitY;
    // 28 complete flap cycles per ambient loop, with no phase jump.
    final flap = .62 + .38 * math.sin(tau * 28 * progress + phase).abs();
    final fade = .88 + .12 * math.sin(tau * 4 * progress + phase).abs();
    final angle = .13 * math.sin(tau * progress + phase);
    return Positioned(
      key: key,
      left: x - size / 2,
      top: y - size / 2,
      width: size,
      height: size,
      child: Opacity(
        opacity: fade,
        child: Transform.rotate(
          angle: angle,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
              (flip ? -1.0 : 1.0) * flap,
              .94 + .08 * math.sin(tau * 6 * progress + phase).abs(),
              1,
            ),
            child: GardenImage.asset(_activeButterflyAsset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildWateringCanOverlay(double width, double height, double progress) {
    if (progress <= 0 || progress >= 1) return const <Widget>[];
    final fade = math.min(1.0, (1 - progress) * 3).toDouble();
    final scene = Size(width, height);
    final size = GardenSceneGeometry.wateringCanSize(scene);
    final center = GardenSceneGeometry.wateringCanCenter(scene, progress);
    final angle = GardenSceneGeometry.wateringCanAngle(progress);
    return [
      Positioned(
        left: center.dx - size / 2,
        top: center.dy - size / 2,
        width: size,
        height: size,
        child: Opacity(
          opacity: fade,
          child: Transform.rotate(
            angle: angle,
            alignment: Alignment.center,
            child: GardenImage.asset(_activeWateringCanAsset, fit: BoxFit.contain),
          ),
        ),
      ),
    ];
  }

  Widget _buildChecklist() {
    final completed = _completed;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: _glassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today’s Checklist',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Complete habits to earn water for your tree 💧',
                    style: TextStyle(color: Color(0xFFD1DFD9), fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _habits.isEmpty ? 0 : completed / _habits.length,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(10),
                        color: _mint,
                        backgroundColor: const Color(0xAA527368),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$completed/${_habits.length}',
                        style: const TextStyle(color: _mint, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!_reminderEnabled && _habits.any((h) => h.reminderEnabled))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Material(
              key: const ValueKey('reminder-master-warning'),
              color: const Color(0xED4A3828),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Row(children: [
                  const Icon(Icons.notifications_off_outlined, color: _gold),
                  const SizedBox(width: 8),
                  const Expanded(child: Text(
                    'Habit reminders are paused because master notifications are off.',
                    style: TextStyle(fontSize: 12),
                  )),
                  TextButton(onPressed: () => _configureReminder(true),
                    child: const Text('Enable')),
                ]),
              ),
            ),
          ),
        Expanded(
          child: _habits.isEmpty
              ? const Center(child: Text('Plant your first daily habit 🌱'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 3, 16, 8),
                  itemCount: _habits.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _habitTile(_habits[index]),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 3, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _addHabit,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add a daily habit'),
              style: FilledButton.styleFrom(
                foregroundColor: _deepNavy,
                backgroundColor: _mint,
                minimumSize: const Size(0, 52),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _iconDataForKey(String key) {
    for (final choice in _habitIconChoices) {
      if (choice.key == key) return choice.value;
    }
    return Icons.spa_outlined;
  }

  IconData _iconFor(Habit habit) {
    if (habit.iconKey.isNotEmpty) return _iconDataForKey(habit.iconKey);
    final title = habit.title.toLowerCase();
    if (title.contains('water') || title.contains('drink')) return Icons.local_drink_outlined;
    if (title.contains('read') || title.contains('book') || title.contains('study')) {
      return Icons.menu_book_outlined;
    }
    if (title.contains('save') || title.contains('money')) return Icons.savings_outlined;
    if (title.contains('walk') || title.contains('move') || title.contains('run')) {
      return Icons.directions_run_outlined;
    }
    return Icons.spa_outlined;
  }

  Widget _habitTile(Habit habit) {
    final credited = _progress.wasCredited(_today, habit.id);
    return Material(
      color: _glass,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => _toggleHabit(habit),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            children: [
              SizedBox(
                height: 44, width: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xAA1E4947),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconFor(habit), color: _gold, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          decoration: habit.completed ? TextDecoration.lineThrough : null,
                        )),
                    Text(credited ? 'Water earned today' : 'Complete to earn +1 water',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFBBD1CA))),
                    if (habit.reminderEnabled)
                      Text('Reminder ${TimeOfDay(hour: habit.reminderHour, minute: habit.reminderMinute).format(context)}${_reminderEnabled ? '' : ' · paused'}',
                        style: const TextStyle(fontSize: 10, color: _gold)),
                  ],
                ),
              ),
              const Icon(Icons.water_drop_rounded, size: 16, color: _blue),
              const SizedBox(width: 2),
              Text(credited ? '✓' : '+1', style: const TextStyle(color: _blue, fontSize: 12)),
              Checkbox(
                key: ValueKey('habit-${habit.id}'),
                value: habit.completed,
                onChanged: (_) => _toggleHabit(habit),
                activeColor: _mint,
                checkColor: _deepNavy,
              ),
              PopupMenuButton<String>(
                tooltip: 'Habit options',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'remove') _removeHabit(habit);
                  if (value == 'edit') _editHabit(habit);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit habit')),
                  PopupMenuItem(value: 'remove', child: Text('Remove habit')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String title, Color accent) =>
      _glassPanel(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 25),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFFCFDFD8))),
          ],
        ),
      );

  Widget _buildStats() {
    final now = DateTime.now();
    final days = List<DateTime>.generate(7, (i) =>
        DateTime(now.year, now.month, now.day - (6 - i)));
    final values = days.map((day) => _progress.earnedOn(todayLocalKey(day))).toList();
    final maxValue = math.max(1, values.fold<int>(0, (a, b) => math.max(a, b)));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      children: [
        const Text('Your Progress', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const Text('Every small win adds up.',
            style: TextStyle(color: Color(0xFFD7E9DD), fontSize: 12)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _statCard(Icons.local_fire_department_rounded,
              '${_progress.dayStreak(now)}', 'Day streak', _gold)),
          const SizedBox(width: 10),
          Expanded(child: _statCard(Icons.water_drop_rounded,
              '${_progress.totalEarned}', 'Water earned', _blue)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _statCard(Icons.task_alt_rounded,
              '${_progress.totalEarned}', 'Habits completed', _mint)),
          const SizedBox(width: 10),
          Expanded(child: _statCard(Icons.spa_rounded,
              '${_progress.treeStage + 1} / 6', 'Tree stage', _mint)),
        ]),
        const SizedBox(height: 16),
        _glassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This week', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Water earned from daily checklists',
                  style: TextStyle(fontSize: 11, color: Color(0xFFD1DFD9))),
              const SizedBox(height: 17),
              SizedBox(
                height: 132,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < days.length; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${values[i]}',
                                style: const TextStyle(color: _blue, fontSize: 10)),
                            const SizedBox(height: 5),
                            Container(
                              width: 22,
                              height: 8 + 75 * values[i] / maxValue,
                              decoration: BoxDecoration(
                                color: i == 6 ? _mint : const Color(0xFF5DC8A3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                                [days[i].weekday - 1],
                                style: const TextStyle(fontSize: 9, color: Color(0xFFDBE7E3))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _glassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tree growth • ${_progress.xp} XP',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _activeTreeImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => Column(
                    children: [
                      SizedBox(
                        width: 62, height: 62,
                        child: Opacity(
                          opacity: i <= _progress.treeStage ? 1 : .40,
                          child: GardenImage.asset(_activeTreeImages[i], fit: BoxFit.contain),
                        ),
                      ),
                      Text('${i + 1}', style: TextStyle(
                        fontSize: 11,
                        color: i <= _progress.treeStage ? _mint : Colors.white60,
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              LinearProgressIndicator(
                value: progressToNextStage(_progress.xp),
                backgroundColor: const Color(0xFF527368),
                color: _mint,
                minHeight: 6,
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 8),
              Text('${_progress.totalSpent} water drops used to grow your tree',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFD1DFD9))),
            ],
          ),
        ),
      ],
    );
  }

}

class _HabitDraft {
  const _HabitDraft({required this.title, required this.iconKey,
      required this.reminderEnabled, required this.hour, required this.minute});
  final String title;
  final String iconKey;
  final bool reminderEnabled;
  final int hour;
  final int minute;
}

class _HabitComposer extends StatefulWidget {
  const _HabitComposer({this.initial, required this.masterEnabled,
      required this.onEnableMaster});
  final Habit? initial;
  final bool masterEnabled;
  final Future<bool> Function() onEnableMaster;

  @override
  State<_HabitComposer> createState() => _HabitComposerState();
}

class _HabitComposerState extends State<_HabitComposer> {
  late final TextEditingController _controller;
  late String _iconKey;
  late bool _hasReminder;
  late bool _masterActive;
  bool _enablingMaster = false;
  late TimeOfDay _reminderTime;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial?.title ?? '');
    _iconKey = widget.initial?.iconKey ?? 'leaf';
    _hasReminder = widget.initial?.reminderEnabled ?? false;
    _masterActive = widget.masterEnabled;
    _reminderTime = TimeOfDay(hour: widget.initial?.reminderHour ?? 20,
        minute: widget.initial?.reminderMinute ?? 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, _HabitDraft(title: title, iconKey: _iconKey,
      reminderEnabled: _hasReminder,
      hour: _reminderTime.hour, minute: _reminderTime.minute));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context, initialTime: _reminderTime,
      helpText: 'Remind me about this habit',
    );
    if (picked != null && mounted) setState(() => _reminderTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: math.max(190.0, MediaQuery.sizeOf(context).height * .86 - keyboard)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.initial == null ? 'Plant a new habit' : 'Edit habit',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text('Small actions grow into something beautiful.'),
                const SizedBox(height: 15),
                TextField(
                  controller: _controller,
                  autofocus: widget.initial == null,
                  maxLength: 48,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'e.g. Read 10 pages',
                    filled: true,
                    fillColor: const Color(0xFF234640),
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const Text('Pick an icon',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: [
                    for (final choice in _habitIconChoices)
                      Semantics(
                        button: true, selected: _iconKey == choice.key,
                        label: '${choice.key} habit icon',
                        child: InkWell(
                          onTap: () => setState(() => _iconKey = choice.key),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 54, height: 54,
                            decoration: BoxDecoration(
                              color: _iconKey == choice.key
                                  ? const Color(0xFF2A5F56) : const Color(0xFF234640),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _iconKey == choice.key ? _mint : const Color(0x556FC09D),
                                width: _iconKey == choice.key ? 1.6 : 1,
                              ),
                            ),
                            child: Icon(choice.value,
                                color: _iconKey == choice.key ? _mint : _gold, size: 26),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  key: const ValueKey('habit-reminder-toggle'),
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_active_outlined, color: _mint),
                  title: const Text('Remind me daily'),
                  subtitle: Text(_masterActive
                      ? 'Set a time for this habit' : 'Master notifications are OFF — reminders will be paused'),
                  value: _hasReminder,
                  onChanged: (value) => setState(() => _hasReminder = value),
                ),
                if (_hasReminder && !_masterActive)
                  Container(
                    key: const ValueKey('composer-master-off-warning'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4C3B26),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Master notifications are disabled. This habit will NOT notify you until enabled.',
                          style: TextStyle(color: Color(0xFFFFE5AC), fontSize: 12)),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          key: const ValueKey('composer-enable-master'),
                          onPressed: _enablingMaster ? null : () async {
                            setState(() => _enablingMaster = true);
                            final success = await widget.onEnableMaster();
                            if (!mounted) return;
                            setState(() { _enablingMaster = false; _masterActive = success; });
                          },
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: Text(_enablingMaster ? 'Enabling...' : 'Enable master notifications'),
                        ),
                      ],
                    ),
                  ),
                if (_hasReminder)
                  ListTile(
                    key: const ValueKey('habit-reminder-time'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.schedule_rounded, color: _gold),
                    title: const Text('Reminder time'),
                    subtitle: Text(_reminderTime.format(context)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickTime,
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(backgroundColor: _mint,
                      foregroundColor: _deepNavy,
                      padding: const EdgeInsets.symmetric(vertical: 15)),
                    child: Text(widget.initial == null ? 'Create habit' : 'Save changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _EditorAssetChoice {
  const _EditorAssetChoice({
    required this.id,
    required this.label,
    this.assetPath,
  });

  final String id;
  final String label;
  final String? assetPath;
}

/// Ground plane: a contact shadow and a sunlit patch under the tree roots.
class _GroundContactPainter extends CustomPainter {
  const _GroundContactPainter({required this.moonlight});
  final bool moonlight;

  @override
  void paint(Canvas canvas, Size size) {
    final shadowRect = Rect.fromLTWH(
      size.width * .13,
      size.height * .34,
      size.width * .74,
      size.height * .30,
    );
    final glowRect = Rect.fromLTWH(
      size.width * .22,
      size.height * .29,
      size.width * .56,
      size.height * .24,
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..color = (moonlight ? const Color(0x9C0B1832) : const Color(0x8E11231A))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: moonlight
              ? const [Color(0x7E7C7398), Color(0x44334853), Color(0x003A4568)]
              : const [Color(0x7AA78554), Color(0x3A58673A), Color(0x00324729)],
          stops: const [0, .56, 1],
        ).createShader(glowRect),
    );
  }

  @override
  bool shouldRepaint(covariant _GroundContactPainter oldDelegate) =>
      oldDelegate.moonlight != moonlight;
}


/// Screen-space drops pour into the existing soil contact point. Entirely
/// painted above the tree; never affects its constraints or root baseline.
class _WateringPainter extends CustomPainter {
  const _WateringPainter(this.progress, this.ground, this.placement, this.spout);
  final double progress;
  final PlantingGround ground;
  final GardenTreePlacement placement;
  final Offset spout;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress >= 1) return;
    final fade = math.min(1.0, (1 - progress) * 3);
    final origin = GardenSceneGeometry.wateringSpout(size, progress, nozzle: spout);
    // Match the visible sprite's actual root/soil contact (about 91% of
    // its 512px art box), including scale and the user's drag offset.
    final treeSize = GardenSceneGeometry.treeSize(size) *
        GardenSceneGeometry.treeVisualScale(ground: ground) * placement.scale;
    final treeBottom = GardenSceneGeometry.groundBottom(size, ground: ground) -
        GardenSceneGeometry.treeBottomLift(treeSize, ground: ground) -
        placement.dy * size.height;
    final target = Offset(
      size.width * (.5 + placement.dx),
      size.height - treeBottom - treeSize *
          (ground == PlantingGround.defaultGarden ||
           ground == PlantingGround.moonlightGarden ? .09 : .065),
    );
    final p = Paint()..color = _blue.withValues(alpha: fade);

    // Repeated bright droplets travel a curved stream to the fixed tree base.
    for (var i = 0; i < 26; i++) {
      final t = (progress * 1.55 + i / 26) % 1.0;
      final x = origin.dx + (target.dx - origin.dx) * t -
          25 * math.sin(t * math.pi) + math.sin(i * 2.8) * 4;
      final y = origin.dy + (target.dy - origin.dy) * t * t;
      final r = 2.3 + (i % 4) * .45;
      canvas.drawCircle(Offset(x, y), r * 2.4,
          Paint()..color = _blue.withValues(alpha: fade * .13));
      canvas.drawCircle(Offset(x, y), r, p);
    }
    if (progress > .33) {
      final burst = (1 - progress).clamp(0.0, 1.0);
      for (var i = 0; i < 12; i++) {
        final angle = (math.pi * 2 * i) / 12;
        final dist = 8 + progress * 29;
        final x = target.dx + math.cos(angle) * dist;
        final y = target.dy + math.sin(angle) * dist * .45;
        canvas.drawCircle(Offset(x, y), 1.4 + (i % 3),
            Paint()..color = _mint.withValues(alpha: fade * burst));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WateringPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.ground != ground ||
      oldDelegate.placement.dx != placement.dx ||
      oldDelegate.placement.dy != placement.dy ||
      oldDelegate.spout != spout;
}
