import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'account_api.dart';

class LegalPage extends StatefulWidget {
  const LegalPage({super.key, required this.api, this.document});
  final AccountApi api;
  final String? document;
  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  Map<String, dynamic>? _legal;
  bool _offline = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic> data;
    try {
      data = await widget.api.send('GET', '/v1/legal');
    } catch (_) {
      data = Map<String, dynamic>.from(
          jsonDecode(await rootBundle.loadString('assets/legal/policies.json'))
              as Map);
      _offline = true;
    }
    if (mounted) setState(() => _legal = data);
  }

  @override
  Widget build(BuildContext context) {
    final documents = _legal?['documents'] as Map?;
    final selected = documents?[widget.document] as Map?;
    return Scaffold(
      appBar:
          AppBar(title: Text(selected?['title'] as String? ?? 'Help & legal')),
      body: documents == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Policy version ${_legal!['version']}',
                          style: Theme.of(context).textTheme.labelMedium),
                      if (_offline)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                                'Bundled copy. Connect to view the current operator and published policy.')),
                      const SizedBox(height: 20),
                      if (selected != null)
                        SelectableText(selected['body'] as String,
                            style: const TextStyle(height: 1.6))
                      else
                        ...documents.entries.map((entry) => ListTile(
                              title:
                                  Text((entry.value as Map)['title'] as String),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => LegalPage(
                                          api: widget.api,
                                          document: entry.key as String))),
                            )),
                      const SizedBox(height: 16),
                      OutlinedButton(
                          onPressed: () => showLicensePage(
                              context: context, applicationName: 'BetterSeed'),
                          child: const Text('Open-source licenses')),
                    ]),
              ))),
    );
  }
}
