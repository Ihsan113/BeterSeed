import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:betterseed/account/account_api.dart';
import 'package:betterseed/account/cloud_account.dart';
import 'package:betterseed/account/play_billing.dart';

class BillingAccount extends CloudAccount {
  BillingAccount() : super(api: AccountApi(baseUrl: 'https://api.example.com'));
  bool loggedIn = true;
  bool failVerification = false;
  Completer<Map<String, dynamic>>? verifyResult;
  int verified = 0;
  int balance = 0;
  @override
  bool get signedIn => loggedIn;
  @override
  String? get userId => loggedIn ? 'user-a' : null;
  @override
  Map<String, dynamic>? get user =>
      {'id': 'user-a', 'billingAccountId': 'opaque-billing-account'};
  @override
  Map<String, dynamic>? get wallet =>
      {'balance': balance, 'billingAvailable': true};
  @override
  Future<void> refreshWallet() async {}
  @override
  Future<Map<String, dynamic>> verifyPurchase(
      String productId, String purchaseToken) async {
    verified++;
    expect(purchaseToken, 'google-purchase-token');
    if (failVerification)
      throw const AccountException('play_verification_unavailable');
    final result = await (verifyResult?.future ??
        Future.value({'verified': true, 'consumed': true, 'balance': 120}));
    balance = result['balance'] as int;
    return result;
  }
}

class FakePlay implements BillingGateway {
  final events = StreamController<List<PurchaseDetails>>.broadcast();
  int completed = 0;
  bool? autoConsumed;
  PurchaseParam? buyParam;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => events.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: ids
            .map((id) => ProductDetails(
                id: id,
                title: id,
                description: '',
                price: 'Rp10.000',
                rawPrice: 10000,
                currencyCode: 'IDR'))
            .toList(),
        notFoundIDs: [],
      );
  @override
  Future<bool> buyConsumable(
      {required PurchaseParam purchaseParam, required bool autoConsume}) async {
    buyParam = purchaseParam;
    autoConsumed = autoConsume;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed++;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}
}

PurchaseDetails purchased([PurchaseStatus status = PurchaseStatus.purchased]) =>
    PurchaseDetails(
      purchaseID: 'untrusted-local-id',
      productID: 'betterseed_coin_120',
      transactionDate: '123',
      status: status,
      verificationData: PurchaseVerificationData(
          localVerificationData: 'untrusted',
          serverVerificationData: 'google-purchase-token',
          source: 'google_play'),
    )..pendingCompletePurchase = true;
Future<void> settle() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BillingAccount account;
  late FakePlay play;
  late PlayBilling billing;
  setUp(() {
    account = BillingAccount();
    play = FakePlay();
    billing = PlayBilling(account, purchase: play)..start();
  });
  tearDown(() async {
    billing.dispose();
    account.dispose();
    await play.events.close();
  });
  test('purchases bind an opaque account ID and disable automatic consumption',
      () async {
    await settle();
    await billing.buy(CoinBundle.catalog.first);
    expect(play.autoConsumed, false);
    expect(play.buyParam!.applicationUserName, 'opaque-billing-account');
  });
  test('does not grant or acknowledge before server commits and consumes',
      () async {
    await settle();
    account.verifyResult = Completer();
    play.events.add([purchased()]);
    await settle();
    expect(account.verified, 1);
    expect(account.balance, 0);
    expect(play.completed, 0);
    account.verifyResult!
        .complete({'verified': true, 'consumed': true, 'balance': 120});
    await settle();
    expect(account.balance, 120);
    expect(play.completed, 1);
  });
  test(
      'verification failure leaves purchase uncompleted and retry delivers later',
      () async {
    await settle();
    account.failVerification = true;
    play.events.add([purchased()]);
    await settle();
    expect(play.completed, 0);
    expect(account.balance, 0);
    account.failVerification = false;
    await billing.retry();
    await settle();
    expect(account.balance, 120);
    expect(play.completed, 1);
  });
  test('server consumption pending never completes the Play purchase early',
      () async {
    await settle();
    account.verifyResult = Completer()
      ..complete({'verified': true, 'consumed': false, 'balance': 120});
    play.events.add([purchased()]);
    await settle();
    expect(account.balance, 120);
    expect(play.completed, 0);
    expect(billing.canBuy, false);
  });
  test('guest and pending-payment events never deliver coins', () async {
    await settle();
    account.loggedIn = false;
    play.events.add([purchased(PurchaseStatus.pending), purchased()]);
    await settle();
    expect(account.verified, 0);
    expect(play.completed, 0);
    expect(account.balance, 0);
  });
}
