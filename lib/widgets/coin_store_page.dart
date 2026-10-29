import 'package:flutter/material.dart';
import '../account/cloud_account.dart';
import '../account/play_billing.dart';

class BetterSeedCoinStorePage extends StatefulWidget {
  const BetterSeedCoinStorePage(
      {super.key, required this.account, required this.billing});
  final CloudAccount account;
  final PlayBilling billing;
  @override
  State<BetterSeedCoinStorePage> createState() =>
      _BetterSeedCoinStorePageState();
}

class _BetterSeedCoinStorePageState extends State<BetterSeedCoinStorePage> {
  @override
  void initState() {
    super.initState();
    widget.billing.addListener(_changed);
    widget.account.addListener(_changed);
    widget.billing.retry();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.billing.removeListener(_changed);
    widget.account.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billing = widget.billing;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Leaf Coins')),
      body: SafeArea(
          child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colors.primaryContainer,
                                  colors.surfaceContainerHigh
                                ])),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.spa_rounded,
                                  color: colors.primary, size: 30),
                              const SizedBox(height: 16),
                              Text('Your balance',
                                  style: TextStyle(
                                      color: colors.onSurfaceVariant)),
                              const SizedBox(height: 4),
                              Text('${widget.account.wallet?['balance'] ?? 0}',
                                  key: const ValueKey('coin-store-balance'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const Text('Leaf Coins'),
                              if (widget.account.user?['email'] != null) ...[
                                const SizedBox(height: 16),
                                Text(widget.account.user!['email'] as String,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: colors.onSurfaceVariant)),
                              ],
                            ])),
                    const SizedBox(height: 28),
                    Text('Make your garden yours',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                        'Choose a coin bundle to unlock your favourite garden packs.',
                        style: TextStyle(
                            color: colors.onSurfaceVariant, height: 1.5)),
                    const SizedBox(height: 20),
                    if (billing.loading || billing.verifying) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(billing.verifying
                          ? 'Adding your coins…'
                          : 'Loading prices…'),
                      const SizedBox(height: 16),
                    ],
                    if (billing.message != null) ...[
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: colors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(14)),
                          child: Text(billing.message!,
                              style: const TextStyle(height: 1.5))),
                      const SizedBox(height: 16),
                    ],
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 500 &&
                              MediaQuery.textScalerOf(context).scale(14) <= 20
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(spacing: 12, runSpacing: 12, children: [
                        for (final bundle in CoinBundle.catalog)
                          SizedBox(width: width, child: _bundle(bundle)),
                      ]);
                    }),
                    const SizedBox(height: 24),
                    const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user_outlined, size: 16),
                          SizedBox(width: 8),
                          Flexible(
                              child: Text('Secure payment with Google Play',
                                  style: TextStyle(fontSize: 12))),
                        ]),
                    const SizedBox(height: 20),
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Already paid but missing coins?'),
                        children: [
                          const Text(
                              'Check the BetterSeed account used for your purchase, then check delivery. You don’t need to buy again.',
                              style: TextStyle(height: 1.5)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                              onPressed: billing.loading || billing.verifying
                                  ? null
                                  : billing.retry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Check purchase delivery')),
                          const SizedBox(height: 12),
                        ]),
                    const SizedBox(height: 12),
                    Text(
                        'Coins and packs stay with your BetterSeed account. Refunded purchases are deducted from your balance.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: colors.onSurfaceVariant)),
                  ])),
        ),
      )),
    );
  }

  Widget _bundle(CoinBundle bundle) {
    final billing = widget.billing;
    final colors = Theme.of(context).colorScheme;
    final product = billing.products[bundle.productId];
    return Container(
      key: ValueKey('coin-bundle-${bundle.coins}'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(bundle.title,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.spa_rounded, color: colors.primary, size: 24),
              Text('${bundle.coins}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Text('Leaf Coins', style: TextStyle(fontSize: 13)),
            ]),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: billing.canBuy && product != null
                ? () => billing.buy(bundle)
                : null,
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(
                billing.buying == bundle.productId
                    ? 'Waiting for payment…'
                    : product?.price ?? 'Unavailable right now',
                textAlign: TextAlign.center)),
      ]),
    );
  }
}
