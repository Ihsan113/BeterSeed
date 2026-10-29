import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backup/local_backup_files.dart';
import 'account_api.dart';
import 'cloud_account.dart';
import 'legal_page.dart';
import 'dart:convert';

enum _AuthStep { login, register, verify, forgot, reset, factor }

class AccountPage extends StatefulWidget {
  const AccountPage(
      {super.key, required this.account, this.initialChoice = false});
  final CloudAccount account;
  final bool initialChoice;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _scroll = ScrollController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _factor = TextEditingController();
  _AuthStep _step = _AuthStep.login;
  bool _busy = false, _accepted = false, _showPassword = false;
  bool _legalReady = false;
  String _legalVersion = '';
  String? _message;
  String? _challengeId;
  String? _challengeToken;
  CloudAccount get a => widget.account;
  @override
  void initState() {
    super.initState();
    a.addListener(_changed);
    _loadLegal();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLegal() async {
    if (!a.configured) return;
    try {
      final result = await a.api.send('GET', '/v1/legal');
      if (mounted)
        setState(() {
          _legalReady = true;
          _legalVersion = result['version'] as String;
        });
    } on AccountException catch (e) {
      if (mounted) setState(() => _message = e.toString());
    }
  }

  @override
  void dispose() {
    a.removeListener(_changed);
    _scroll.dispose();
    for (final controller in [_email, _password, _code, _factor]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    final previousStep = _step;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on AccountException catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } catch (_) {
      if (mounted)
        setState(() =>
            _message = 'Unable to complete this action. Please try again.');
    } finally {
      if (mounted) {
        if (_step != previousStep && _scroll.hasClients) _scroll.jumpTo(0);
        setState(() => _busy = false);
      }
    }
  }

  void _go(_AuthStep step) {
    FocusScope.of(context).unfocus();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _step = step;
      _challengeId = null;
      _challengeToken = null;
      _message = null;
      _password.clear();
      _code.clear();
      _factor.clear();
    });
  }

  Future<void> _finishAuth(Map<String, dynamic> result) async {
    if (result['twoFactorRequired'] == true) {
      setState(() {
        _challengeId = result['challengeId'] as String;
        _challengeToken = result['challengeToken'] as String;
        _step = _AuthStep.factor;
        _password.clear();
      });
      return;
    }
    await a.acceptSession(result);
    _password.clear();
    _factor.clear();
    _code.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('betterseed_account_choice_v1', true);
    if (mounted) setState(() => _step = _AuthStep.login);
  }

  Future<void> _submit() => _run(() async {
        final email = _email.text.trim().toLowerCase();
        switch (_step) {
          case _AuthStep.login:
            await _finishAuth(await a.api.send('POST', '/v1/auth/login',
                body: {'email': email, 'password': _password.text}));
          case _AuthStep.register:
            if (!_accepted || !_legalReady) return;
            final result = await a.api.send('POST', '/v1/auth/register', body: {
              'email': email,
              'password': _password.text,
              'acceptTerms': true,
              'legalVersion': _legalVersion
            });
            setState(() {
              _challengeId = result['challengeId'] as String;
              _step = _AuthStep.verify;
              _password.clear();
              _message =
                  'Check your inbox for a verification code. If you already have an account, sign in instead.';
            });
          case _AuthStep.verify:
            await _finishAuth(
                await a.api.send('POST', '/v1/auth/verify-email', body: {
              'challengeId': _challengeId,
              'code': _code.text.trim(),
              'acceptTerms': _accepted,
              'legalVersion': _legalVersion
            }));
          case _AuthStep.forgot:
            final result = await a.api.send('POST', '/v1/auth/forgot-password',
                body: {'email': email});
            setState(() {
              _challengeId = result['challengeId'] as String;
              _step = _AuthStep.reset;
              _message =
                  'If this is an eligible email account, a reset code will arrive shortly.';
            });
          case _AuthStep.reset:
            await a.api.send('POST', '/v1/auth/reset-password', body: {
              'challengeId': _challengeId,
              'code': _code.text.trim(),
              'password': _password.text,
              'factor': _factor.text.trim()
            });
            _go(_AuthStep.login);
            setState(() =>
                _message = 'Password reset. Sign in with your new password.');
          case _AuthStep.factor:
            await _finishAuth(
                await a.api.send('POST', '/v1/auth/two-factor', body: {
              'challengeId': _challengeId,
              'challengeToken': _challengeToken,
              'factor': _factor.text.trim()
            }));
        }
      });
  Future<void> _google() => _run(() async {
        if (!_legalReady) await _loadLegal();
        if (!_legalReady || !mounted) return;
        if (!_accepted) {
          final consent = await showDialog<bool>(
              context: context,
              builder: (dialog) => AlertDialog(
                    title: const Text('Before you continue'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'By continuing, you confirm that you meet the minimum age and agree to our Terms and Privacy policy.'),
                      _policyLinks(),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('Agree & continue'))
                    ],
                  ));
          if (consent != true || !mounted) return;
          _accepted = true;
        }
        final token = await GoogleAccountIdentity.authenticate();
        await _finishAuth(await a.api.send('POST', '/v1/auth/google', body: {
          'idToken': token,
          'acceptTerms': true,
          'legalVersion': _legalVersion
        }));
      });
  Future<void> _guest() async {
    await (await SharedPreferences.getInstance())
        .setBool('betterseed_account_choice_v1', true);
    if (mounted) Navigator.of(context).pop();
  }

  Future<Map<String, dynamic>?> _reauth(
      {bool newPassword = false, bool deleting = false}) async {
    final google = a.user?['provider'] == 'google';
    final twoFactor = a.user?['twoFactorEnabled'] == true;
    final fields = <String, String>{
      if (!google) 'password': 'Current password',
      if (newPassword) 'newPassword': 'New password (12–128 characters)',
      if (twoFactor) 'factor': 'Authenticator or recovery code',
      if (deleting) 'confirmation': 'Type DELETE to confirm',
    };
    final values = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _ProofDialog(
              title: deleting
                  ? 'Delete account permanently?'
                  : 'Confirm your identity',
              fields: fields,
              description: deleting
                  ? 'Your cloud garden, account, coin balance and pack access will be removed. This does not refund purchases. Export your garden first. Clear app data on your other devices to erase any remaining offline copies.'
                  : google
                      ? 'Continue to verify your Google account again.'
                      : 'Re-enter your password to protect your account.',
              action: deleting ? 'Delete permanently' : 'Continue',
            ));
    if (values == null) return null;
    if (google) values['idToken'] = await GoogleAccountIdentity.authenticate();
    return values;
  }

  Future<void> _setupFactor() => _run(() async {
        final proof = await _reauth();
        if (proof == null) return;
        final setup = await a.authorized('POST', '/v1/account/two-factor/setup',
            body: proof);
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => _AuthenticatorSetup(account: a, setup: setup)));
        await a.refreshUser();
      });
  Future<void> _disableFactor() => _run(() async {
        final proof = await _reauth();
        if (proof == null) return;
        await a.authorized('POST', '/v1/account/two-factor/disable',
            body: proof);
        await a.refreshUser();
      });
  Future<void> _changePassword() => _run(() async {
        final proof = await _reauth(newPassword: true);
        if (proof == null) return;
        await a.authorized('POST', '/v1/account/password', body: proof);
        await a.signOut();
        if (mounted)
          setState(() =>
              _message = 'Password changed. Sign in again on each device.');
      });
  Future<void> _delete() => _run(() async {
        final proof = await _reauth(deleting: true);
        if (proof == null) return;
        await a.authorized('DELETE', '/v1/account', body: proof);
        await a.signOut(deleted: true);
        if (mounted)
          setState(() => _message =
              'Account deleted. You are now using your guest garden.');
      });
  Future<void> _signOut() => _run(() async {
        final yes = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: Text(a.dirty
                      ? 'Some changes are still on this device. They will stay in this account’s local copy until you sign in again. Your guest garden is separate.'
                      : 'Your guest garden will open. Sign in again to return to this account.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign out'))
                  ],
                ));
        if (yes == true) await a.signOut();
      });
  void _legal([String? document]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => LegalPage(api: a.api, document: document)));
  Widget _field(TextEditingController controller, String label,
          {bool secret = false,
          TextInputType? keyboard,
          Iterable<String>? autofill}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: controller,
          enabled: !_busy,
          obscureText: secret && !_showPassword,
          autocorrect: false,
          enableSuggestions: !secret,
          keyboardType: keyboard,
          autofillHints: autofill,
          maxLength: secret ? 128 : 254,
          decoration: InputDecoration(
              labelText: label,
              counterText: '',
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: .35),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              suffixIcon: secret
                  ? IconButton(
                      tooltip:
                          _showPassword ? 'Hide password' : 'Show password',
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(_showPassword
                          ? Icons.visibility_off
                          : Icons.visibility))
                  : null),
        ),
      );
  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy && !a.switching,
        child: Scaffold(
          appBar: AppBar(
              title: Text(a.signedIn && !a.needsSignIn
                  ? 'Your account'
                  : 'BetterSeed')),
          body: SingleChildScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_busy || a.switching) const LinearProgressIndicator(),
                      if (_message != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(_message!, semanticsLabel: _message)),
                      if (a.signedIn && !a.needsSignIn)
                        ..._signedIn()
                      else
                        ..._signedOut(),
                      const SizedBox(height: 24),
                      TextButton(
                          onPressed: () => _legal(),
                          child: const Text('Help & information')),
                    ]),
              ))),
        ),
      );
  List<Widget> _signedOut() {
    final login = _step == _AuthStep.login;
    final registering = _step == _AuthStep.register;
    final headline = switch (_step) {
      _AuthStep.login =>
        a.needsSignIn ? 'Welcome back' : 'Your garden, with you',
      _AuthStep.register => 'Start growing together',
      _AuthStep.verify => 'Verify your email',
      _AuthStep.forgot => 'Forgot your password?',
      _AuthStep.reset => 'Choose a new password',
      _AuthStep.factor => 'One more step',
    };
    final description = switch (_step) {
      _AuthStep.login => 'Sign in to pick up where you left off.',
      _AuthStep.register => 'Keep your habits and garden safe across devices.',
      _AuthStep.verify =>
        'Enter the code sent to your email. It expires in 10 minutes.',
      _AuthStep.forgot =>
        'We’ll send a reset code to your email. For Google accounts, use Google’s account recovery.',
      _AuthStep.reset =>
        'Enter your email code and a password with at least 12 characters.',
      _AuthStep.factor =>
        'Enter a code from your authenticator or an unused recovery code.',
    };
    final button = switch (_step) {
      _AuthStep.login => 'Sign in',
      _AuthStep.register => 'Create account',
      _AuthStep.verify => 'Verify email',
      _AuthStep.forgot => 'Send reset code',
      _AuthStep.reset => 'Reset password',
      _AuthStep.factor => 'Verify sign-in',
    };
    return [
      const SizedBox(height: 12),
      Align(
          alignment: Alignment.centerLeft,
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20)),
              child: Icon(Icons.spa_outlined,
                  size: 32,
                  color: Theme.of(context).colorScheme.onPrimaryContainer))),
      const SizedBox(height: 24),
      Text(headline,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(description,
          style: TextStyle(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 28),
      if (!a.configured) ...[
        const Text(
            'Sign-in is unavailable right now. You can still grow your garden as a guest.'),
        const SizedBox(height: 20),
      ],
      if (login ||
          registering ||
          _step == _AuthStep.forgot ||
          (_step == _AuthStep.verify && _challengeId == null))
        _field(_email, 'Email',
            keyboard: TextInputType.emailAddress,
            autofill: const [AutofillHints.email]),
      if (login || registering || _step == _AuthStep.reset)
        _field(_password, login ? 'Password' : 'Password (12–128 characters)',
            secret: true,
            autofill: [
              login ? AutofillHints.password : AutofillHints.newPassword
            ]),
      if (login)
        Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: _busy ? null : () => _go(_AuthStep.forgot),
                child: const Text('Forgot password?'))),
      if (_step == _AuthStep.verify || _step == _AuthStep.reset)
        _field(_code, '6-digit email code',
            keyboard: TextInputType.number,
            autofill: const [AutofillHints.oneTimeCode]),
      if (_step == _AuthStep.factor)
        _field(_factor, 'Authenticator / recovery code'),
      if (_step == _AuthStep.reset)
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Use two-factor authentication?'),
            children: [
              _field(_factor, 'Authenticator / recovery code (if enabled)')
            ]),
      if (registering || _step == _AuthStep.verify) ...[
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _accepted,
            onChanged:
                _busy ? null : (v) => setState(() => _accepted = v ?? false),
            title: const Text(
                'I meet the minimum age and agree to the Terms and Privacy policy.',
                style: TextStyle(fontSize: 13, height: 1.4))),
        _policyLinks(),
        if (!_legalReady && a.configured)
          TextButton(
              onPressed: _loadLegal,
              child: const Text('Try loading policies again')),
        const SizedBox(height: 12),
      ],
      FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: !_busy &&
                  a.configured &&
                  (!registering || (_accepted && _legalReady)) &&
                  (_step != _AuthStep.verify ||
                      (_challengeId != null && _accepted && _legalReady))
              ? _submit
              : null,
          child: Text(button)),
      if (login || registering) ...[
        const SizedBox(height: 16),
        const Row(children: [
          Expanded(child: Divider()),
          Padding(
              padding: EdgeInsets.symmetric(horizontal: 16), child: Text('or')),
          Expanded(child: Divider())
        ]),
        const SizedBox(height: 16),
        OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            onPressed: !_busy && a.configured && googleWebClientId.isNotEmpty
                ? _google
                : null,
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('Continue with Google')),
        const SizedBox(height: 12),
        TextButton(
            onPressed: _busy
                ? null
                : () => _go(login ? _AuthStep.register : _AuthStep.login),
            child: Text(login
                ? 'Create an email account'
                : 'Already have an account? Sign in')),
      ] else ...[
        const SizedBox(height: 12),
        TextButton(
            onPressed: _busy ? null : () => _go(_AuthStep.login),
            child: const Text('Back to sign in')),
      ],
      if (_step == _AuthStep.verify)
        TextButton(
            onPressed: !_busy && a.configured
                ? () => _run(() async {
                      final result = await a.api.send(
                          'POST', '/v1/auth/resend-verification',
                          body: {'email': _email.text.trim().toLowerCase()});
                      setState(() {
                        _challengeId = result['challengeId'] as String;
                        _message =
                            'If your email is awaiting verification, a new code is on its way.';
                      });
                    })
                : null,
            child: const Text('Send a new verification code')),
      if (login)
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Need help signing in?',
                style: TextStyle(fontSize: 14)),
            children: [
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mark_email_unread_outlined),
                  title: const Text('Verify an existing email registration'),
                  onTap: _busy ? null : () => _go(_AuthStep.verify))
            ]),
      const SizedBox(height: 20),
      TextButton(
          onPressed: _busy ? null : _guest,
          child:
              Text(a.needsSignIn ? 'Continue offline' : 'Continue as guest')),
      if (login) _policyLinks(),
    ];
  }

  Widget _policyLinks() =>
      Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
        TextButton(
            onPressed: () => _legal('privacy'),
            child: const Text('Privacy policy')),
        TextButton(
            onPressed: () => _legal('terms'),
            child: const Text('Terms of use')),
      ]);

  List<Widget> _signedIn() => [
        Text(a.user!['email'] as String,
            style: Theme.of(context).textTheme.titleLarge),
        Text(a.user!['provider'] == 'google'
            ? 'Google account'
            : 'Verified email account'),
        const SizedBox(height: 24),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(a.status,
                          style: Theme.of(context).textTheme.titleMedium),
                      if (a.lastSynced != null)
                        Text(
                            'Last synced: ${DateTime.parse(a.lastSynced!).toLocal().toString().split('.').first}'),
                      if (a.error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(a.error!)),
                      const SizedBox(height: 12),
                      const Text(
                          'Your garden saves automatically while you use the app. Your music stays on this phone.'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                          onPressed:
                              _busy || a.busy ? null : () => _run(a.sync),
                          icon: const Icon(Icons.sync),
                          label: const Text('Sync now')),
                      if (a.conflict != null) ...[
                        const Divider(),
                        const Text(
                            'Both garden versions are preserved. Choose the version you want to keep. Water and XP will not be added together.'),
                        Text(
                            'This device: ${((a.currentGarden?['progress'] as Map?)?['xp']) ?? 0} XP · Cloud: ${((a.conflict?['snapshot'] as Map?)?['progress'] as Map?)?['xp'] ?? 0} XP'),
                        FilledButton(
                            onPressed: _busy || a.busy
                                ? null
                                : () => _run(
                                    () => a.resolveConflict(useCloud: true)),
                            child: const Text('Use cloud garden')),
                        OutlinedButton(
                            onPressed: _busy || a.busy
                                ? null
                                : () => _run(
                                    () => a.resolveConflict(useCloud: false)),
                            child: const Text('Keep this device’s garden')),
                      ],
                      if (a.recoveryCopy != null)
                        TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                      await LocalBackupFiles.saveJson(
                                          contents: jsonEncode(a.recoveryCopy),
                                          suggestedName:
                                              'BetterSeed-sync-recovery.json');
                                    }),
                            child: const Text('Save a copy of both gardens')),
                    ]))),
        const SizedBox(height: 20),
        Text('Security', style: Theme.of(context).textTheme.titleMedium),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.security),
            title: const Text('Authenticator'),
            subtitle: Text(a.user!['twoFactorEnabled'] == true
                ? 'Two-factor authentication is on'
                : 'Protect your account with an authenticator'),
            trailing: TextButton(
                onPressed: _busy
                    ? null
                    : a.user!['twoFactorEnabled'] == true
                        ? _disableFactor
                        : _setupFactor,
                child: Text(a.user!['twoFactorEnabled'] == true
                    ? 'Disable'
                    : 'Set up'))),
        if (a.user!['provider'] == 'email')
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.password),
              title: const Text('Change password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : _changePassword),
        const Divider(),
        OutlinedButton(
            onPressed: _busy ? null : _signOut, child: const Text('Sign out')),
        TextButton(
            onPressed: _busy ? null : _delete,
            child: Text('Delete account permanently',
                style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ];
}

class _ProofDialog extends StatefulWidget {
  const _ProofDialog(
      {required this.title,
      required this.description,
      required this.fields,
      required this.action});
  final String title, description, action;
  final Map<String, String> fields;
  @override
  State<_ProofDialog> createState() => _ProofDialogState();
}

class _ProofDialogState extends State<_ProofDialog> {
  late final controllers = {
    for (final key in widget.fields.keys) key: TextEditingController()
  };
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.description),
          const SizedBox(height: 16),
          ...widget.fields.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: controllers[e.key],
                obscureText: e.key.toLowerCase().contains('password'),
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                    labelText: e.value, border: const OutlineInputBorder()),
              ))),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context,
                  {for (final e in controllers.entries) e.key: e.value.text}),
              child: Text(widget.action))
        ],
      );
}

class _AuthenticatorSetup extends StatefulWidget {
  const _AuthenticatorSetup({required this.account, required this.setup});
  final CloudAccount account;
  final Map<String, dynamic> setup;
  @override
  State<_AuthenticatorSetup> createState() => _AuthenticatorSetupState();
}

class _AuthenticatorSetupState extends State<_AuthenticatorSetup> {
  final _code = TextEditingController();
  List<dynamic>? _recovery;
  bool _busy = false, _saved = false;
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.account.authorized(
          'POST', '/v1/account/two-factor/confirm',
          body: {'factor': _code.text.trim()});
      if (mounted) setState(() => _recovery = result['recoveryCodes'] as List);
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy && (_recovery == null || _saved),
        child: Scaffold(
          appBar: AppBar(title: const Text('Set up authenticator')),
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_recovery == null) ...[
                        const Text(
                            'Scan this QR code in Google Authenticator, Aegis, or another TOTP app. Setup expires after 10 minutes.'),
                        const SizedBox(height: 20),
                        Center(
                            child: QrImageView(
                                data: widget.setup['uri'] as String,
                                size: 220,
                                backgroundColor: Colors.white)),
                        const SizedBox(height: 16),
                        const Text('Or enter this secret manually:'),
                        SelectableText(widget.setup['secret'] as String),
                        const SizedBox(height: 20),
                        TextField(
                            controller: _code,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: '6-digit authenticator code',
                                border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _busy ? null : _confirm,
                            child:
                                const Text('Enable two-factor authentication')),
                      ] else ...[
                        Text('Save your recovery codes',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 16),
                        const Text(
                            'Each code can be used once if you lose your authenticator. They are shown only now. Store them somewhere safe outside this phone.'),
                        const SizedBox(height: 16),
                        SelectableText(_recovery!.join('\n'),
                            style: const TextStyle(
                                fontFamily: 'monospace', height: 1.8)),
                        CheckboxListTile(
                            value: _saved,
                            onChanged: (v) =>
                                setState(() => _saved = v ?? false),
                            title:
                                const Text('I saved my recovery codes safely')),
                        FilledButton(
                            onPressed:
                                _saved ? () => Navigator.pop(context) : null,
                            child: const Text('Done')),
                      ],
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(_error!)),
                    ]),
              ))),
        ),
      );
}
