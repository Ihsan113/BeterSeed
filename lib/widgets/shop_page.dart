import '../data/pack_downloads.dart';
import '../account/pack_catalog.dart';
import '../data/garden_pack_registry.dart';
import 'package:flutter/material.dart';

import '../data/shop_loadout.dart';
import 'garden_pack_preview.dart';

export '../data/shop_loadout.dart';

const _mint = Color(0xFF9EF7BD);
const _moon = Color(0xFFCBB4FF);
const _sakuraPink = Color(0xFFFFB9DB);
const _autumn = Color(0xFFFFC56E);
const _ink = Color(0xFF081F25);

class BetterSeedShopPage extends StatefulWidget {
  const BetterSeedShopPage({
    super.key,
    this.catalog,
    this.downloads,
    this.ownedPacks = const {},
    this.onAcquire,
    this.acquiring = false,
    this.loadout = ShopLoadout.defaultPack,
    this.moonlightOwned = false,
    this.sakuraOwned = false,
    this.autumnOwned = false,
    this.leafCoins = 0,
    this.onApplyLoadout,
    this.onEditAssets,
    this.onOpenCoinStore,
    this.currentStage = 0,
    this.animatePreviews = true,
  });
  final PackCatalog? catalog;
  final PackDownloadService? downloads;
  final Set<String> ownedPacks;
  final ValueChanged<GardenOffer>? onAcquire;
  final bool acquiring;
  final ShopLoadout loadout;
  final bool moonlightOwned;
  final bool sakuraOwned;
  final bool autumnOwned;
  final int leafCoins;
  final ValueChanged<ShopLoadout>? onApplyLoadout;
  final VoidCallback? onEditAssets;
  final VoidCallback? onOpenCoinStore;
  final int currentStage;
  final bool animatePreviews;

  @override
  State<BetterSeedShopPage> createState() => _BetterSeedShopPageState();
}

class _BetterSeedShopPageState extends State<BetterSeedShopPage> {
  int _tab = 0;

  void _equip(String id) {
    widget.onApplyLoadout?.call(
      GardenPackRegistry.find(id)?.loadout ?? ShopLoadout.defaultPack,
    );
  }

  void _preview(String id, String title) {
    final packId = id.replaceFirst('owned-', '');
    if (!GardenPackFiles.hasPack(packId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Download this pack first to preview all 6 stages.')));
      return;
    }
    final pack =
        GardenPackRegistry.find(id.replaceFirst('owned-', ''))?.loadout ??
            ShopLoadout.defaultPack;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GardenPackPreview(
        title: title,
        loadout: pack,
        initialStage: widget.currentStage,
        animate: widget.animatePreviews,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('shop-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Garden Packs',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          const Text(
              'Unlock premium looks with leaf coins or equip the packs you already own.',
              style: TextStyle(fontSize: 12, color: Color(0xFFDEEAE5))),
          if (widget.loadout.isMixed) ...[
            const SizedBox(height: 9),
            const Text(
              'Your custom garden look is active',
              key: ValueKey('shop-custom-mix-active'),
              style: TextStyle(fontSize: 12, color: _mint),
            ),
          ],
          const SizedBox(height: 14),
          // The coin balance must remain readable at 320dp and at large
          // accessibility text sizes. On compact screens, the CTA moves to a
          // full-width second row instead of squeezing the balance label.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xDD082E31),
              border: Border.all(color: const Color(0x8067BDA4)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 375 ||
                    MediaQuery.textScalerOf(context).scale(14) > 19;
                final balance = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0x1F9EF7BD),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.spa_rounded, color: _mint),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Leaf coin balance',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFFD0DED8))),
                          const SizedBox(height: 2),
                          Text('${widget.leafCoins} leaves',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                );
                final getCoins = FilledButton.icon(
                  key: const ValueKey('shop-open-coin-store'),
                  onPressed: widget.onOpenCoinStore,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Get coins'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _mint,
                    foregroundColor: _ink,
                    minimumSize: const Size(118, 46),
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      balance,
                      const SizedBox(height: 12),
                      getCoins,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: balance),
                    const SizedBox(width: 12),
                    getCoins,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xDD082E31),
              border: Border.all(color: const Color(0x8067BDA4)),
              borderRadius: BorderRadius.circular(17),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                    child: _tabButton(
                        'Shop', 0, const ValueKey('shop-store-tab'))),
                Expanded(
                    child: _tabButton('My Collection', 1,
                        const ValueKey('shop-collection-tab'))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._dynamicCards(),
        ],
      ),
    );
  }

  Widget _tabButton(String title, int id, Key key) {
    final selected = _tab == id;
    return TextButton(
      key: key,
      onPressed: () => setState(() => _tab = id),
      style: TextButton.styleFrom(
        backgroundColor:
            selected ? const Color(0xFF5364A0) : Colors.transparent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        title,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  List<Widget> _dynamicCards() {
    final catalog = widget.catalog;
    final owned = {
      'default',
      ...widget.ownedPacks,
      if (widget.moonlightOwned) 'moonlight',
      if (widget.sakuraOwned) 'sakura',
      if (widget.autumnOwned) 'golden_autumn'
    };
    final offers = {
      for (final offer in catalog?.offers ?? <GardenOffer>[]) offer.id: offer
    };
    // Thumbnails for all packs live in the base install; a pack can be shown
    // even before the admin has activated its offer in the commercial API.
    final items = _tab == 1
        ? GardenPackRegistry.packs.where((p) => owned.contains(p.id)).toList()
        : GardenPackRegistry.packs;
    return [
      if (catalog?.online != true)
        _hint(
            'You’re offline or the Shop is unavailable. Your collection is still here. Connect to claim or unlock a pack.'),
      if (catalog?.loading == true) const LinearProgressIndicator(),
      Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
              onPressed: catalog?.loading == true ? null : catalog?.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh shop'))),
      for (final pack in items) ...[
        _packCard(
            id: _tab == 1 ? 'owned-${pack.id}' : pack.id,
            title: offers[pack.id]?.name ?? pack.name,
            subtitle: offers[pack.id]?.description ?? 'Your garden collection',
            image: pack.thumbnail ?? pack.background,
            active: widget.loadout.matches(pack.loadout),
            owned: owned.contains(pack.id),
            installed: GardenPackFiles.hasPack(pack.id),
            downloading: widget.downloads?.downloading(pack.id) ?? false,
            downloadProgress: widget.downloads?.progress(pack.id) ?? 0,
            downloadSize: widget.downloads?.info(pack.id)?.sizeLabel,
            downloadError: widget.downloads?.error(pack.id),
            published: offers[pack.id]?.status == 'active',
            onDownload: () async {
              final ok = await widget.downloads?.download(pack.id) ?? false;
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                ok ? '${pack.name} is ready to use.' :
                (widget.downloads?.configured == true
                  ? 'Download failed. Please check storage or internet and retry.'
                  : 'Pack hosting is not configured for this build.'))));
            },
            onRemove: () async {
              await widget.downloads?.remove(pack.id);
              if (mounted) setState(() {});
            },
            premium: !owned.contains(pack.id) &&
                offers[pack.id]?.accessType == 'premium',
            leafPrice: offers[pack.id]?.price ?? 0,
            leafBalance: widget.leafCoins,
            onTap: owned.contains(pack.id)
                ? () => _tab == 0 ? setState(() => _tab = 1) : _equip(pack.id)
                : catalog?.online == true &&
                        !widget.acquiring &&
                        offers[pack.id]?.status == 'active' &&
                        catalog!.assetReady(pack.id)
                    ? () => offers[pack.id]!.price > 0 &&
                            offers[pack.id]!.price > widget.leafCoins
                        ? widget.onOpenCoinStore?.call()
                        : widget.onAcquire?.call(offers[pack.id]!)
                    : null),
        const SizedBox(height: 14),
      ],
      if (_tab == 1)
        FilledButton.icon(
            key: const ValueKey('collection-edit-assets'),
            onPressed: widget.onEditAssets,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Customize garden')),
      if (_tab == 0 && items.length <= 1)
        _hint(
            'More garden packs will appear when the Shop is available for this app version.'),
    ];
  }

  Widget _packCard({
    required String id,
    required String title,
    required String subtitle,
    required String image,
    required bool active,
    required bool owned,
    required bool installed,
    required bool downloading,
    required double downloadProgress,
    required String? downloadSize,
    required String? downloadError,
    required bool published,
    required VoidCallback onDownload,
    required VoidCallback onRemove,
    required VoidCallback? onTap,
    bool premium = false,
    int leafPrice = 0,
    int leafBalance = 0,
  }) {
    final autumn = id.contains('autumn');
    final moon = id.contains('moonlight');
    final highlight = id.contains('sakura')
        ? _sakuraPink
        : autumn
            ? _autumn
            : moon
                ? _moon
                : _mint;
    final enoughCoins = leafBalance >= leafPrice;
    final needsDownload = owned && !installed;
    final buttonText = downloading
        ? 'Downloading ${(downloadProgress * 100).round()}%'
        : needsDownload
            ? 'Download • ${downloadSize ?? '? MB'}'
        : active && installed
        ? 'In Use'
        : !owned
            ? premium
                ? enoughCoins
                    ? 'Unlock • $leafPrice leaves'
                    : 'Get more leaves'
                : 'Claim Free'
            : (_tab == 0 ? 'My Collection' : 'Use');
    return Container(
      key: ValueKey('shop-pack-$id'),
      decoration: BoxDecoration(
        color: const Color(0xF20B2831),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
            color: active ? highlight : highlight.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Stack(
              children: [
                Image.asset(image,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    cacheWidth: 720),
                Positioned(
                  top: 9,
                  right: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xDD102C31),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Text(
                        active
                            ? 'IN USE'
                            : owned
                                ? 'OWNED'
                                : !published
                                    ? 'SOON'
                                    : premium
                                        ? 'PREMIUM'
                                        : 'FREE',
                        style: TextStyle(
                            color: highlight,
                            fontSize: 11,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                if (premium)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xD0102C31),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: highlight.withValues(alpha: .45)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.spa_rounded, size: 13, color: highlight),
                            const SizedBox(width: 4),
                            Text('$leafPrice leaves',
                                style: TextStyle(
                                    color: highlight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFDBE5E1), height: 1.35)),
                if (downloadSize != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.download_for_offline_outlined, size: 14, color: _mint),
                    const SizedBox(width: 6),
                    Expanded(child: Text(installed
                        ? 'Installed · ${downloadSize} download'
                        : 'Optional download · $downloadSize',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFCEE8E0)))),
                  ]),
                ],
                if (!published && !owned) ...[
                  const SizedBox(height: 8),
                  const Text('Not released in the Shop yet',
                    style: TextStyle(fontSize: 11, color: Color(0xFFE7CC90))),
                ],
                if (downloading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: downloadProgress.clamp(0, 1)),
                ],
                if (downloadError != null && !installed) ...[
                  const SizedBox(height: 6),
                  Text('Download failed · retry available',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFFFBD9F))),
                ],
                if (premium && !owned) ...[
                  const SizedBox(height: 10),
                  Text(
                    enoughCoins
                        ? 'Ready to unlock with your current balance.'
                        : 'Need ${leafPrice - leafBalance} more leaf coins to unlock this pack.',
                    style: TextStyle(
                        fontSize: 11,
                        color: enoughCoins ? _mint : const Color(0xFFFFD989)),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: ValueKey('shop-preview-$id'),
                    onPressed: () => _preview(id, title),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Preview pack'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: ValueKey('shop-action-$id'),
                    onPressed: downloading ? null
                        : needsDownload ? onDownload
                        : active ? null : onTap,
                    icon: Icon(
                      needsDownload ? Icons.download_rounded : active
                          ? Icons.check_circle_outline
                          : owned
                              ? Icons.auto_awesome_outlined
                              : premium
                                  ? Icons.lock_open_rounded
                                  : Icons.card_giftcard_outlined,
                      size: 18,
                    ),
                    label: Text(buttonText,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    style: FilledButton.styleFrom(
                      backgroundColor: highlight,
                      foregroundColor: _ink,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                if (installed && owned && !active && id.replaceFirst('owned-', '') != 'default')
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: ValueKey('shop-remove-$id'),
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline, size: 15),
                      label: const Text('Remove downloaded files'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hint(String message) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xD70B2A31),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: _mint, size: 19),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: const TextStyle(fontSize: 12, height: 1.5))),
          ],
        ),
      );
}
