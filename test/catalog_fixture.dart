import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:betterseed/account/account_api.dart';
import 'package:betterseed/account/pack_catalog.dart';
import 'package:betterseed/data/garden_pack_registry.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<PackCatalog> fixtureCatalog() async {
  SharedPreferences.setMockInitialValues({});
  final catalog = PackCatalog(AccountApi(
      baseUrl: 'https://catalog.test',
      client: MockClient((_) async => http.Response(
          jsonEncode({
            'version': 1,
            'packs': [
              for (final p in GardenPackRegistry.packs)
                {
                  'packId': p.id,
                  'name': p.name,
                  'description': 'A complete garden set',
                  'accessType': p.id == 'default' ? 'free' : 'premium',
                  'priceCoins': switch (p.id) {
                    'moonlight' => 180,
                    'sakura' => 280,
                    'golden_autumn' => 420,
                    _ => 160
                  },
                  'status': 'active',
                  'minimumAppBuild': 1,
                  'revision': 1,
                  'displayOrder': 0
                }
            ]
          }),
          200))));
  await catalog.load();
  return catalog;
}
