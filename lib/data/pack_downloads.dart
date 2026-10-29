import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'garden_pack_registry.dart';

/// Only public CDN files go here. Never point this at the authenticated API or
/// expose user credentials to a content host.
const packCdnBaseUrl = String.fromEnvironment('BETTERSEED_PACK_CDN_BASE_URL');

class PackArchiveInfo {
  const PackArchiveInfo(this.file, this.sizeBytes, this.sha256, this.revision);
  final String file, sha256;
  final int sizeBytes, revision;
  String get sizeLabel => '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// File paths in the catalog are *logical Flutter paths*. Remote content is
/// stored at the same relative paths inside a validated per-pack directory.
class GardenPackFiles {
  GardenPackFiles._();
  static final Map<String, Directory> _roots = {};
  static bool hasPack(String id) => id == 'default' || _roots.containsKey(id);
  static void setRoot(String id, Directory? root) {
    if (root == null) {
      _roots.remove(id);
    } else {
      _roots[id] = root;
    }
  }

  static File? fileFor(String logicalPath) {
    if (!logicalPath.startsWith('assets/')) return null;
    if (logicalPath.startsWith('assets/images/shop/')) return null;
    for (final pack in GardenPackRegistry.packs) {
      if (pack.id == 'default') continue;
      if (!pack.assets.contains(logicalPath)) continue;
      final root = _roots[pack.id];
      if (root == null) return null;
      return File('${root.path}/$logicalPath');
    }
    return null;
  }

  static ImageProvider provider(String path) {
    final file = fileFor(path);
    return file == null ? AssetImage(path) : FileImage(file);
  }
}

class GardenImage {
  const GardenImage._();
  static Widget asset(String path, {Key? key, double? width, double? height,
    BoxFit? fit, AlignmentGeometry alignment = Alignment.center,
    FilterQuality filterQuality = FilterQuality.low, int? cacheWidth,
    bool gaplessPlayback = false}) => Image(
      key: key, image: cacheWidth == null ? GardenPackFiles.provider(path) :
        ResizeImage(GardenPackFiles.provider(path), width: cacheWidth),
      width: width, height: height, fit: fit, alignment: alignment,
      filterQuality: filterQuality,
      gaplessPlayback: gaplessPlayback,
    );
}

/// Per-pack opt-in downloads. A ZIP is never treated as a proof of ownership:
/// the Shop still relies on the verified wallet and server catalog.
class PackDownloadService extends ChangeNotifier {
  PackDownloadService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  Directory? _root;
  final Map<String, PackArchiveInfo> _manifest = {};
  final Map<String, double> _progress = {};
  final Set<String> _busy = {};
  final Map<String, String> _errors = {};
  bool initialized = false;
  bool _disposed = false;
  Future<void>? _initialization;

  PackArchiveInfo? info(String id) => _manifest[id];
  bool installed(String id) => GardenPackFiles.hasPack(id);
  bool downloading(String id) => _busy.contains(id);
  double progress(String id) => _progress[id] ?? 0;
  String? error(String id) => _errors[id];
  bool get configured {
    final uri = Uri.tryParse(packCdnBaseUrl);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty &&
        uri.userInfo.isEmpty && uri.query.isEmpty && uri.fragment.isEmpty;
  }

  // The first-load background scan and an immediate Shop download may request
  // initialization together. Share one in-flight scan instead of opening the
  // same files twice. Failed scans can be retried safely.
  Future<void> initialize() async {
    if (initialized || _disposed) return;
    final work = _initialization ??= _scanInstalledPacks();
    try {
      await work;
    } finally {
      if (!initialized) _initialization = null;
    }
  }

  Future<void> _scanInstalledPacks() async {
    final raw = jsonDecode(await rootBundle.loadString('assets/pack_downloads.json')) as Map;
    if (raw['schema'] != 1 || raw['packs'] is! Map) throw const FormatException('Pack manifest version');
    for (final item in (raw['packs'] as Map).entries) {
      final id = item.key as String;
      if (id == 'default' || GardenPackRegistry.find(id) == null) continue;
      final meta = Map<String, dynamic>.from(item.value as Map);
      final name = meta['file'] as String;
      final digest = meta['sha256'] as String;
      final size = meta['sizeBytes'] as int;
      final revision = meta['revision'] as int;
      if (!RegExp(r'^[a-z0-9_-]+-r[0-9]+\.zip$').hasMatch(name) ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
          size <= 0 || size > 120 * 1024 * 1024 || revision < 1) {
        throw const FormatException('Invalid pack manifest');
      }
      _manifest[id] = PackArchiveInfo(name, size, digest, revision);
    }
    try {
      _root = Directory('${(await getApplicationSupportDirectory()).path}/garden_packs');
      await _root!.create(recursive: true);
      for (final entry in _manifest.entries) {
        final dir = Directory('${_root!.path}/${entry.key}');
        if (await _isComplete(dir, entry.key, entry.value)) {
          GardenPackFiles.setRoot(entry.key, dir);
        }
      }
    } on MissingPluginException {
      // Widget tests / unsupported platforms stay on Original Garden.
    }
    initialized = true;
    notifyListeners();
  }

  Future<bool> _isComplete(Directory dir, String id, PackArchiveInfo meta) async {
    try {
      final record = jsonDecode(await File('${dir.path}/installed.json').readAsString()) as Map;
      if (record['sha256'] != meta.sha256 || record['revision'] != meta.revision) return false;
      for (final path in GardenPackRegistry.find(id)!.assets) {
        if (path.endsWith('_pack_thumb.webp') || path.endsWith('_pack_thumbnail.webp')) continue;
        if (!await File('${dir.path}/$path').exists()) return false;
      }
      return true;
    } catch (_) { return false; }
  }

  Future<bool> download(String id) async {
    if (!initialized) await initialize();
    final meta = _manifest[id];
    if (meta == null || _root == null || !configured || downloading(id)) return false;
    if (installed(id)) return true;
    _busy.add(id); _progress[id] = 0; _errors.remove(id); notifyListeners();
    final working = Directory('${_root!.path}/.$id.tmp');
    final destination = Directory('${_root!.path}/$id');
    try {
      if (await working.exists()) await working.delete(recursive: true);
      await working.create(recursive: true);
      final uri = Uri.parse('${packCdnBaseUrl.replaceFirst(RegExp(r'/$'), '')}/${meta.file}');
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await _client.send(request).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) throw StateError('Download HTTP ${response.statusCode}');
      final archiveFile = File('${working.path}/download.zip');
      final sink = archiveFile.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream.timeout(const Duration(seconds: 35))) {
          received += chunk.length;
          if (received > meta.sizeBytes) throw StateError('Unexpected file size');
          sink.add(chunk);
          _progress[id] = received / meta.sizeBytes;
          notifyListeners();
        }
      } finally { await sink.close(); }
      if (received != meta.sizeBytes) throw StateError('Incomplete download');
      final actual = (await sha256.bind(archiveFile.openRead()).first).toString();
      if (actual != meta.sha256) throw StateError('Download checksum mismatch');
      final bytes = await archiveFile.readAsBytes();
      final contents = ZipDecoder().decodeBytes(bytes, verify: true);
      final pack = GardenPackRegistry.find(id)!;
      final expected = {pack.background, ...pack.trees, pack.butterfly, pack.wateringCan,
        if (pack.video != null) pack.video!};
      if (contents.length != expected.length) throw StateError('Unexpected archive entries');
      var expanded = 0;
      for (final entry in contents) {
        if (!entry.isFile || !expected.remove(entry.name)) throw StateError('Unsafe archive path');
        expanded += entry.size;
        if (expanded > 100 * 1024 * 1024) throw StateError('Archive too large');
        final target = File('${working.path}/${entry.name}');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(entry.content as List<int>, flush: false);
      }
      if (expected.isNotEmpty) throw StateError('Missing pack assets');
      await archiveFile.delete();
      await File('${working.path}/installed.json').writeAsString(jsonEncode({
        'sha256': meta.sha256, 'revision': meta.revision,
      }), flush: true);
      if (await destination.exists()) await destination.delete(recursive: true);
      await working.rename(destination.path);
      GardenPackFiles.setRoot(id, destination);
      _progress[id] = 1;
      return true;
    } catch (error) {
      _errors[id] = '$error';
      return false;
    } finally {
      if (await working.exists()) await working.delete(recursive: true);
      _busy.remove(id);
      notifyListeners();
    }
  }

  Future<bool> remove(String id) async {
    if (id == 'default' || _busy.contains(id) || _root == null) return false;
    GardenPackFiles.setRoot(id, null);
    final dir = Directory('${_root!.path}/$id');
    try { if (await dir.exists()) await dir.delete(recursive: true); }
    catch (_) { return false; }
    notifyListeners();
    return true;
  }

  // A background scan can finish after the page is unmounted; notifying a
  // disposed ChangeNotifier would be an assertion failure in widget tests.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}
