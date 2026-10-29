import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'account_api.dart';
import 'cloud_account.dart';

class CoinBundle {
  const CoinBundle(this.productId, this.coins, this.title);
  final String productId, title;
  final int coins;
  static const catalog = [
    CoinBundle('betterseed_coin_120', 120, 'Seed Pouch'),
    CoinBundle('betterseed_coin_300', 300, 'Garden Purse'),
    CoinBundle('betterseed_coin_650', 650, 'Bloom Crate'),
    CoinBundle('betterseed_coin_1400', 1400, 'Legendary Vault'),
  ];
}

abstract class BillingGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids);
  Future<bool> buyConsumable(
      {required PurchaseParam purchaseParam, required bool autoConsume});
  Future<void> completePurchase(PurchaseDetails purchase);
  Future<void> restorePurchases({String? applicationUserName});
}

class GooglePlayGateway implements BillingGateway {
  final InAppPurchase _purchase = InAppPurchase.instance;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchase.purchaseStream;
  @override
  Future<bool> isAvailable() => _purchase.isAvailable();
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) =>
      _purchase.queryProductDetails(ids);
  @override
  Future<bool> buyConsumable(
          {required PurchaseParam purchaseParam, required bool autoConsume}) =>
      _purchase.buyConsumable(
          purchaseParam: purchaseParam, autoConsume: autoConsume);
  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _purchase.completePurchase(purchase);
  @override
  Future<void> restorePurchases({String? applicationUserName}) =>
      _purchase.restorePurchases(applicationUserName: applicationUserName);
}

/// App-scoped listener: purchases continue processing after the store is closed.
/// The backend commits the grant before consuming on Google Play. Nothing here
/// grants coins or trusts a purchaseID, timestamp, or a local delivery flag.
class PlayBilling extends ChangeNotifier {
  PlayBilling(this.account, {BillingGateway? purchase})
      : _iap = purchase ?? GooglePlayGateway();
  final CloudAccount account;
  final BillingGateway _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Map<String, PurchaseDetails> _pending = {};
  Future<void> _queue = Future.value();
  bool available = false, loading = false, verifying = false;
  bool _retrying = false;
  bool _disposed = false;
  String? buying, message;
  String? _lastAccount;
  Map<String, ProductDetails> products = {};
  DateTime _lastRetry = DateTime.fromMillisecondsSinceEpoch(0);
  bool get canBuy =>
      account.signedIn &&
      !account.needsSignIn &&
      available &&
      account.wallet?['billingAvailable'] == true &&
      !_retrying &&
      buying == null &&
      !verifying &&
      _pending.isEmpty;
  void start() {
    if (_subscription != null || !account.configured) return;
    _subscription = _iap.purchaseStream.listen((purchases) {
      _queue =
          _queue.catchError((Object _) {}).then((_) => _process(purchases));
    }, onError: (Object _) {
      message =
          'Google Play could not report purchases. Retry pending delivery.';
      notifyListeners();
    });
    account.addListener(_accountChanged);
    _accountChanged();
  }

  void _accountChanged() {
    if (_lastAccount != account.userId) {
      _lastAccount = account.userId;
      if (account.signedIn) unawaited(retry());
    } else if (account.signedIn &&
        !_lastRetry
            .isAfter(DateTime.now().subtract(const Duration(minutes: 1)))) {
      unawaited(retry());
    }
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    try {
      available = await _iap.isAvailable();
      if (available) {
        final response = await _iap.queryProductDetails(
            CoinBundle.catalog.map((e) => e.productId).toSet());
        products = {for (final p in response.productDetails) p.id: p};
        if (response.error != null)
          message =
              'Unable to load current Google Play prices. Try again later.';
      } else {
        message = 'Google Play Billing is unavailable on this device.';
      }
    } catch (_) {
      available = false;
      message = 'Unable to connect to Google Play.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> buy(CoinBundle bundle) async {
    if (!canBuy || !products.containsKey(bundle.productId)) return;
    buying = bundle.productId;
    message = null;
    notifyListeners();
    try {
      // Refresh server wallet/readiness before opening the payment sheet.
      await account.refreshWallet();
      if (!account.signedIn || account.wallet?['billingAvailable'] != true)
        throw const AccountException('billing_unavailable');
      final started = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(
            productDetails: products[bundle.productId]!,
            applicationUserName: account.user!['billingAccountId'] as String),
        autoConsume: false,
      );
      if (!started) {
        buying = null;
        message = 'Google Play could not start this purchase.';
      }
    } on AccountException catch (e) {
      buying = null;
      message = e.toString();
    } catch (_) {
      buying = null;
      message = 'The purchase could not start. Please try again.';
    }
    notifyListeners();
  }

  Future<void> _process(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.pending) {
        buying = p.productID;
        message = 'Waiting for Google Play payment confirmation.';
        notifyListeners();
        continue;
      }
      if (p.status == PurchaseStatus.error ||
          p.status == PurchaseStatus.canceled) {
        buying = null;
        message = p.status == PurchaseStatus.canceled
            ? 'Purchase canceled.'
            : 'Google Play could not complete this purchase.';
        notifyListeners();
        continue;
      }
      if (p.status != PurchaseStatus.purchased &&
          p.status != PurchaseStatus.restored) continue;
      final token = p.verificationData.serverVerificationData;
      _pending[token] = p;
      buying = null;
      if (!account.signedIn || account.needsSignIn) {
        message =
            'Sign in to the account used for this purchase to finish delivery.';
        notifyListeners();
        continue;
      }
      verifying = true;
      notifyListeners();
      try {
        final result = await account.verifyPurchase(p.productID, token);
        if (result['verified'] == true && result['consumed'] == true) {
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          _pending.remove(token);
          message = 'Purchase verified. Your account balance is up to date.';
        } else {
          message =
              'Coins are saved to your account. Google Play confirmation will retry automatically.';
        }
      } on AccountException catch (e) {
        message = e.toString();
      } catch (_) {
        message = 'Delivery is still pending. Retry without buying again.';
      } finally {
        verifying = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry() async {
    if (_disposed || _retrying) return;
    _lastRetry = DateTime.now();
    if (!account.signedIn || account.needsSignIn) return;
    _retrying = true;
    await load();
    try {
      await account.refreshWallet();
      if (_pending.isNotEmpty)
        _queue = _queue
            .catchError((Object _) {})
            .then((_) => _process(_pending.values.toList()));
      if (available)
        await _iap.restorePurchases(
            applicationUserName: account.user!['billingAccountId'] as String);
    } on AccountException catch (e) {
      message = e.toString();
    } catch (_) {
      message =
          'Unable to retry pending purchases. Please try again when connected.';
    } finally {
      _retrying = false;
    }
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    account.removeListener(_accountChanged);
    _subscription?.cancel();
    super.dispose();
  }
}
