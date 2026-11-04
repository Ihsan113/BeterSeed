import 'dart:async';
import 'account_surfaces.dart';
import '../ui/app_feedback.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backup/local_backup_files.dart';
import 'account_api.dart';
import 'cloud_account.dart';
import 'legal_page.dart';
import 'dart:convert';

enum _AuthStep {
  login,
  register,
  verifyRequest,
  verify,
  forgot,
  resetEmail,
  resetFactor,
  reset,
  factor
}

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
  bool _resetRecovery = false;
  bool _legalReady = false;
  String _legalVersion = '';
  String? _message;
  NoticeTone _messageTone = NoticeTone.info;
  final _fieldErrors = <TextEditingController, String>{};
  Timer? _resendTimer;
  int _resendSeconds = 0;
  bool _verificationKnown = false;
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
      if (mounted)
        setState(() {
          _message = e.toString();
          _messageTone = NoticeTone.error;
        });
    }
  }

  @override
  void dispose() {
    a.removeListener(_changed);
    _resendTimer?.cancel();
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
      _messageTone = NoticeTone.info;
    });
    FocusScope.of(context).unfocus();
    try {
      await action();
    } on AccountException catch (e) {
      if (mounted)
        setState(() {
          _message = e.toString();
          _messageTone = NoticeTone.error;
          if (e.code == 'email_not_verified' && _step == _AuthStep.login) {
            _step = _AuthStep.verifyRequest;
            _messageTone = NoticeTone.warning;
          }
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _message = 'Unable to complete this action. Please try again.';
          _messageTone = NoticeTone.error;
        });
    } finally {
      if (mounted) {
        if ((_step != previousStep || _message != null) && _scroll.hasClients)
          _scroll.jumpTo(0);
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
      _resetRecovery = false;
      _message = null;
      _messageTone = NoticeTone.info;
      _fieldErrors.clear();
      _resendTimer?.cancel();
      _resendSeconds = 0;
      _verificationKnown = false;
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
    _resendTimer?.cancel();
    _resendSeconds = 0;
    _password.clear();
    _factor.clear();
    _code.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('betterseed_account_choice_v1', true);
    if (mounted) setState(() => _step = _AuthStep.login);
  }

  void _startCooldown() {
    _resendTimer?.cancel();
    _resendSeconds = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _alreadyVerified() {
    _go(_AuthStep.login);
    setState(() {
      _message =
          'This email is already registered and verified. Sign in to continue.';
      _messageTone = NoticeTone.success;
    });
  }

  Future<void> _requestVerification({bool resend = false}) async {
    final result = await a.api.send('POST',
        resend ? '/v1/auth/resend-verification' : '/v1/auth/verification/start',
        body: {
          'email': _email.text.trim().toLowerCase(),
          if (!resend) 'password': _password.text,
        });
    if (!mounted) return;
    if (result['status'] == 'already_verified') {
      _alreadyVerified();
      return;
    }
    setState(() {
      _challengeId = result['challengeId'] as String;
      _step = _AuthStep.verify;
      _verificationKnown = !resend || _verificationKnown;
      _code.clear();
      _fieldErrors.clear();
      _password.clear();
      _message = resend
          ? 'A new verification request is ready. Use the latest code from your inbox.'
          : null;
      _messageTone = NoticeTone.info;
      _startCooldown();
    });
  }

  bool _validateStep() {
    final errors = <TextEditingController, String>{};
    if (const {
          _AuthStep.login,
          _AuthStep.register,
          _AuthStep.verifyRequest,
          _AuthStep.forgot
        }.contains(_step) &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim()))
      errors[_email] = 'Enter a valid email address.';
    if (const {
      _AuthStep.login,
      _AuthStep.register,
      _AuthStep.verifyRequest,
      _AuthStep.reset
    }.contains(_step)) {
      if (_password.text.isEmpty)
        errors[_password] = 'Enter your password.';
      else if ((_step == _AuthStep.register || _step == _AuthStep.reset) &&
          (_password.text.length < 12 || _password.text.length > 128))
        errors[_password] = 'Use 12–128 characters for your password.';
    }
    if ((_step == _AuthStep.verify || _step == _AuthStep.resetEmail) &&
        !RegExp(r'^\d{6}$').hasMatch(_code.text.trim()))
      errors[_code] = 'Enter the 6-digit email code.';
    if (_step == _AuthStep.factor || _step == _AuthStep.resetFactor) {
      if (_factor.text.trim().isEmpty)
        errors[_factor] = 'Enter your verification code.';
      else if (!_resetRecovery &&
          !RegExp(r'^\d{6}$').hasMatch(_factor.text.trim()))
        errors[_factor] = 'Enter the 6-digit code from your authenticator.';
    }
    setState(() {
      _fieldErrors.clear();
      _fieldErrors.addAll(errors);
    });
    return errors.isEmpty;
  }

  Future<void> _submit() async {
    if (!_validateStep()) return;
    await _run(() async {
      final email = _email.text.trim().toLowerCase();
      switch (_step) {
        case _AuthStep.login:
          await _finishAuth(await a.api.send('POST', '/v1/auth/login',
              body: {'email': email, 'password': _password.text}));
        case _AuthStep.verifyRequest:
          await _requestVerification();
        case _AuthStep.register:
          if (!_accepted || !_legalReady) return;
          final result = await a.api.send('POST', '/v1/auth/register', body: {
            'email': email,
            'password': _password.text,
            'acceptTerms': true,
            'legalVersion': _legalVersion
          });
          if (!mounted) return;
          if (result['status'] == 'already_verified') {
            _alreadyVerified();
            return;
          }
          setState(() {
            _challengeId = result['challengeId'] as String;
            _step = _AuthStep.verify;
            _password.clear();
            _message = null;
            _verificationKnown = false;
            _startCooldown();
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
          final result = await a.api
              .send('POST', '/v1/auth/forgot-password', body: {'email': email});
          setState(() {
            _challengeId = result['challengeId'] as String;
            _step = _AuthStep.resetEmail;
            _code.clear();
            _message = null;
          });
        case _AuthStep.resetEmail:
          final result = await a.api
              .send('POST', '/v1/auth/password-reset/verify-email', body: {
            'challengeId': _challengeId,
            'code': _code.text.trim(),
          });
          if (!mounted) return;
          setState(() {
            _challengeId = result['challengeId'] as String;
            _challengeToken = result['resetToken'] as String;
            _step = result['twoFactorRequired'] == true
                ? _AuthStep.resetFactor
                : _AuthStep.reset;
            _code.clear();
            _factor.clear();
          });
        case _AuthStep.resetFactor:
          final result = await a.api
              .send('POST', '/v1/auth/password-reset/verify-factor', body: {
            'challengeId': _challengeId,
            'resetToken': _challengeToken,
            'factor': _factor.text.trim(),
          });
          if (!mounted) return;
          setState(() {
            _challengeId = result['challengeId'] as String;
            _challengeToken = result['resetToken'] as String;
            _factor.clear();
            _step = _AuthStep.reset;
          });
        case _AuthStep.reset:
          await a.api.send('POST', '/v1/auth/password-reset/complete', body: {
            'challengeId': _challengeId,
            'resetToken': _challengeToken,
            'password': _password.text,
          });
          if (!mounted) return;
          _go(_AuthStep.login);
          setState(() =>
              _message = 'Password reset. Sign in with your new password.');
          _messageTone = NoticeTone.success;
        case _AuthStep.factor:
          await _finishAuth(
              await a.api.send('POST', '/v1/auth/two-factor', body: {
            'challengeId': _challengeId,
            'challengeToken': _challengeToken,
            'factor': _factor.text.trim()
          }));
      }
    });
  }

  Future<void> _google() => _run(() async {
        if (!_legalReady) await _loadLegal();
        if (!_legalReady || !mounted) return;
        if (!_accepted) {
          final consent = await showDialog<bool>(
              context: context,
              builder: (dialog) => AppDialog(
                    title: Text(context.tr("Before you continue")),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(context.tr(
                          "By continuing, you confirm that you meet the minimum age and agree to our Terms and Privacy policy.")),
                      _policyLinks(),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: Text(context.tr("Cancel"))),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: Text(context.tr("Agree & continue")))
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
      {bool newPassword = false,
      bool deleting = false,
      bool disabling = false}) async {
    final google = a.user?['provider'] == 'google';
    final twoFactor = a.user?['twoFactorEnabled'] == true;
    final fields = <String, String>{
      if (!google) 'password': 'Current password',
      if (newPassword) 'newPassword': 'New password',
      if (twoFactor) 'factor': 'Authenticator or recovery code',
      if (deleting) 'confirmation': 'Type DELETE to confirm',
    };
    final values = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _ProofDialog(
              title: deleting
                  ? context.tr("Delete account permanently?")
                  : context.tr(disabling
                      ? 'Turn off two-factor authentication?'
                      : newPassword
                          ? 'Change password'
                          : 'Confirm your identity'),
              fields: fields,
              description: deleting
                  ? context.tr(
                      "Your cloud garden, account, coin balance and pack access will be removed. This does not refund purchases. Export your garden first. Clear app data on your other devices to erase any remaining offline copies.")
                  : disabling
                      ? context.tr(
                          'Verify your identity to turn off authenticator protection. Future sign-ins will no longer ask for this code.')
                      : google
                          ? context.tr(
                              "Continue to verify your Google account again.")
                          : context.tr(
                              "Re-enter your password to protect your account."),
              action: deleting
                  ? context.tr("Delete permanently")
                  : context.tr(disabling ? 'Disable' : 'Continue'),
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
        final proof = await _reauth(disabling: true);
        if (proof == null) return;
        await a.authorized('POST', '/v1/account/two-factor/disable',
            body: proof);
        await a.refreshUser();
        if (mounted)
          setState(() {
            _message = 'Two-factor authentication is now off.';
            _messageTone = NoticeTone.warning;
          });
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
            builder: (context) => AppDialog(
                  icon: Icons.logout_rounded,
                  title: Text(context.tr("Sign out?")),
                  content: Text(a.dirty
                      ? context.tr(
                          "Some changes are still on this device. They will stay in this account’s local copy until you sign in again. Your guest garden is separate.")
                      : context.tr(
                          "Your guest garden will open. Sign in again to return to this account.")),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.tr("Cancel"))),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.tr("Sign out")))
                  ],
                ));
        if (yes == true) await a.signOut();
      });
  void _legal([String? document]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => LegalPage(api: a.api, document: document)));
  Widget _field(TextEditingController controller, String label,
          {bool secret = false,
          String? helper,
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
              helperText: helper,
              helperMaxLines: 3,
              errorText: _fieldErrors[controller] == null
                  ? null
                  : context.tr(_fieldErrors[controller]!),
              errorMaxLines: 3,
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
                      tooltip: _showPassword
                          ? context.tr("Hide password")
                          : context.tr("Show password"),
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
          appBar: AppBar(actions: [
            const LanguageButton(),
            IconButton(
                tooltip: context.tr('Help & information'),
                onPressed: _busy ? null : () => _legal(),
                icon: const Icon(Icons.help_outline_rounded))
          ], title: Text(context.tr("Your account"))),
          body: SingleChildScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_busy || a.switching) const LinearProgressIndicator(),
                      if (a.signedIn && !a.needsSignIn)
                        ..._signedIn()
                      else
                        ..._signedOut(),
                    ]),
              ))),
        ),
      );
  List<Widget> _signedOut() {
    final login = _step == _AuthStep.login;
    final registering = _step == _AuthStep.register;
    final requesting = _step == _AuthStep.verifyRequest;
    final verifying = _step == _AuthStep.verify;
    final factor = _step == _AuthStep.factor || _step == _AuthStep.resetFactor;
    final headline = switch (_step) {
      _AuthStep.login => 'Sign in to BetterSeed',
      _AuthStep.register => 'Create your account',
      _AuthStep.verifyRequest => 'Verify your email',
      _AuthStep.verify => 'Enter your email code',
      _AuthStep.forgot => 'Forgot your password?',
      _AuthStep.resetEmail => 'Check your email',
      _AuthStep.resetFactor || _AuthStep.factor => 'Verify your identity',
      _AuthStep.reset => 'Choose a new password',
    };
    final description = switch (_step) {
      _AuthStep.login => 'Sign in to pick up where you left off.',
      _AuthStep.register => 'Keep your habits and garden safe across devices.',
      _AuthStep.verifyRequest =>
        'Enter the email and password you used to register. Request a code before continuing.',
      _AuthStep.verify => _verificationKnown
          ? 'Enter the code sent to your email. It expires in 10 minutes.'
          : 'If this email can be verified, a code will arrive shortly. Enter it below.',
      _AuthStep.forgot =>
        'We’ll send a reset code to your email. For Google accounts, use Google’s account recovery.',
      _AuthStep.resetEmail =>
        'If this is an eligible email account, a reset code will arrive shortly.',
      _AuthStep.resetFactor ||
      _AuthStep.factor =>
        'This account uses two-factor authentication. Choose how to verify it.',
      _AuthStep.reset =>
        'Your identity is verified. Choose a password with at least 12 characters.',
    };
    final button = switch (_step) {
      _AuthStep.login => 'Sign in',
      _AuthStep.register => 'Create account',
      _AuthStep.verifyRequest => 'Send verification code',
      _AuthStep.verify => 'Verify email',
      _AuthStep.forgot => 'Send reset code',
      _AuthStep.resetEmail => 'Verify reset code',
      _AuthStep.resetFactor => 'Verify and continue',
      _AuthStep.reset => 'Reset password',
      _AuthStep.factor => 'Verify sign-in',
    };
    return [
      const SizedBox(height: 12),
      Text(context.tr(headline),
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
      const SizedBox(height: 10),
      Text(context.tr(description),
          style: const TextStyle(
              fontSize: 14, height: 1.5, color: Color(0xFFADC3BE))),
      if (verifying || _step == _AuthStep.resetEmail) ...[
        const SizedBox(height: 16),
        Row(children: [
          const Icon(Icons.mail_outline_rounded,
              size: 17, color: Color(0xFFA7DDE0)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_email.text.trim(),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)))
        ]),
      ],
      const SizedBox(height: 24),
      if (_message != null) ...[
        AppNotice(
            key: const ValueKey('account-message'),
            message: context.tr(_message!),
            tone: _messageTone),
        const SizedBox(height: 20),
      ],
      if (!a.configured) ...[
        AppNotice(
            tone: NoticeTone.warning,
            message: context.tr(
                'Sign-in is unavailable right now. You can still grow your garden as a guest.')),
        const SizedBox(height: 20),
      ],
      if (login || registering || requesting || _step == _AuthStep.forgot)
        _field(_email, context.tr('Email'),
            keyboard: TextInputType.emailAddress,
            autofill: const [AutofillHints.email]),
      if (login || registering || requesting || _step == _AuthStep.reset)
        _field(_password,
            context.tr(_step == _AuthStep.reset ? 'New password' : 'Password'),
            helper: registering || _step == _AuthStep.reset
                ? context.tr('12–128 characters')
                : null,
            secret: true,
            autofill: [
              registering || _step == _AuthStep.reset
                  ? AutofillHints.newPassword
                  : AutofillHints.password
            ]),
      if (login)
        Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: _busy ? null : () => _go(_AuthStep.forgot),
                child: Text(context.tr('Forgot password?')))),
      if (verifying || _step == _AuthStep.resetEmail)
        _field(_code, context.tr('6-digit email code'),
            keyboard: TextInputType.number,
            autofill: const [AutofillHints.oneTimeCode]),
      if (factor) ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final recovery in [false, true])
            ChoiceChip(
                key: ValueKey(recovery
                    ? 'reset-method-recovery'
                    : 'reset-method-authenticator'),
                label: Text(
                    context.tr(recovery ? 'Recovery code' : 'Authenticator')),
                selected: _resetRecovery == recovery,
                onSelected: _busy
                    ? null
                    : (_) => setState(() {
                          _resetRecovery = recovery;
                          _factor.clear();
                          _fieldErrors.clear();
                          _message = null;
                        })),
        ]),
        const SizedBox(height: 16),
        Text(
            context.tr(_resetRecovery
                ? 'Enter a recovery code saved when you enabled two-factor authentication.'
                : 'Enter the 6-digit code from your authenticator.'),
            style: const TextStyle(
                fontSize: 13, height: 1.5, color: Color(0xFFADC3BE))),
        const SizedBox(height: 12),
        _field(_factor,
            context.tr(_resetRecovery ? 'Recovery code' : 'Authenticator code'),
            keyboard:
                _resetRecovery ? TextInputType.text : TextInputType.number),
      ],
      if (registering || requesting) ...[
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _accepted,
            onChanged:
                _busy ? null : (v) => setState(() => _accepted = v ?? false),
            title: Text(
                context.tr(
                    'I meet the minimum age and agree to the Terms and Privacy policy.'),
                style: const TextStyle(fontSize: 12, height: 1.4))),
        _policyLinks(),
      ],
      if ((registering || requesting) && !_legalReady && a.configured)
        TextButton(
            onPressed: _busy ? null : _loadLegal,
            child: Text(context.tr('Reload policies'))),
      const SizedBox(height: 12),
      FilledButton(
          key: const ValueKey('account-submit'),
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          onPressed: !_busy &&
                  a.configured &&
                  (!(registering || requesting) ||
                      (_accepted && _legalReady)) &&
                  (!verifying ||
                      (_challengeId != null && _accepted && _legalReady))
              ? _submit
              : null,
          child: Text(context.tr(button), textAlign: TextAlign.center)),
      if (verifying) ...[
        const SizedBox(height: 8),
        TextButton(
            key: const ValueKey('verification-resend'),
            onPressed: !_busy && a.configured && _resendSeconds == 0
                ? () => _run(() => _requestVerification(resend: true))
                : null,
            child: Text(_resendSeconds > 0
                ? context.tr('Resend in {p0}s', {'p0': _resendSeconds})
                : context.tr('Send a new verification code'))),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(context.tr('No email yet?'),
                style: const TextStyle(fontSize: 13)),
            children: [
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                      context.tr(
                          'Check your spam folder and use the latest code. If this email is already registered, sign in or reset your password.'),
                      style: const TextStyle(fontSize: 13, height: 1.5))),
            ]),
      ],
      if (login || registering) ...[
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(context.tr('or'))),
          const Expanded(child: Divider())
        ]),
        const SizedBox(height: 16),
        OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            onPressed: !_busy && a.configured && googleWebClientId.isNotEmpty
                ? _google
                : null,
            icon: const Icon(Icons.account_circle_outlined),
            label: Text(context.tr('Continue with Google'))),
        const SizedBox(height: 8),
        TextButton(
            onPressed: _busy
                ? null
                : () => _go(login ? _AuthStep.register : _AuthStep.login),
            child: Text(context.tr(login
                ? 'Create an email account'
                : 'Already have an account? Sign in'))),
      ] else ...[
        const SizedBox(height: 8),
        TextButton(
            onPressed: _busy ? null : () => _go(_AuthStep.login),
            child: Text(context.tr('Back to sign in'))),
      ],
      if (login)
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(context.tr('Need help signing in?'),
                style: const TextStyle(fontSize: 13)),
            children: [
              AccountActionTile(
                  icon: Icons.mark_email_unread_outlined,
                  title: context.tr('Verify an existing email registration'),
                  onTap: _busy ? null : () => _go(_AuthStep.verifyRequest))
            ]),
      if (_step == _AuthStep.resetEmail || verifying)
        TextButton(
            onPressed: _busy
                ? null
                : () =>
                    _go(verifying ? _AuthStep.verifyRequest : _AuthStep.forgot),
            child: Text(context.tr('Use a different email'))),
      if (login || registering) ...[
        const SizedBox(height: 12),
        TextButton(
            onPressed: _busy ? null : _guest,
            child: Text(context
                .tr(a.needsSignIn ? 'Continue offline' : 'Continue as guest'))),
      ],
      if (login) _policyLinks(),
    ];
  }

  Widget _policyLinks() =>
      Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
        TextButton(
            onPressed: () => _legal('privacy'),
            child: Text(context.tr("Privacy policy"))),
        TextButton(
            onPressed: () => _legal('terms'),
            child: Text(context.tr("Terms of use"))),
      ]);

  Future<void> _resolveConflict(bool useCloud) => _run(() async {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialog) => AppDialog(
                    icon: Icons.cloud_sync_outlined,
                    tone: NoticeTone.warning,
                    title: Text(context.tr(useCloud
                        ? 'Use cloud garden'
                        : 'Keep this device’s garden')),
                    content: Text(context.tr(
                        'Both garden versions are preserved. Choose the version you want to keep. Water and XP will not be added together.')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: Text(context.tr('Cancel'))),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: Text(context.tr('Continue')))
                    ]));
        if (confirmed == true) await a.resolveConflict(useCloud: useCloud);
      });

  List<Widget> _signedIn() {
    final google = a.user!['provider'] == 'google';
    final enabled = a.user!['twoFactorEnabled'] == true;
    final synced =
        a.lastSynced == null ? null : DateTime.tryParse(a.lastSynced!);
    return [
      AccountPanel(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF203F39),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.person_outline_rounded,
                size: 28, color: Color(0xFF9EF7BD))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.user!['email'] as String,
              style: const TextStyle(
                  fontSize: 16, height: 1.3, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(context.tr(google ? 'Google account' : 'Verified email account'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9EF7BD))),
        ])),
      ])),
      if (_message != null) ...[
        const SizedBox(height: 16),
        AppNotice(message: context.tr(_message!), tone: _messageTone)
      ],
      const SizedBox(height: 20),
      AccountPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.cloud_outlined, color: Color(0xFFA7DDE0), size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Text(context.tr('Cloud sync'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)))
        ]),
        const SizedBox(height: 16),
        Text(context.tr(a.status),
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: a.error != null || a.conflict != null
                    ? const Color(0xFFFFD28E)
                    : const Color(0xFF9EF7BD))),
        if (synced != null) ...[
          const SizedBox(height: 6),
          Text(
              context.tr('Last synced: {p0}', {
                'p0':
                    DateFormat.yMMMd(Localizations.localeOf(context).toString())
                        .add_jm()
                        .format(synced.toLocal())
              }),
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: Color(0xFFADC3BE)))
        ],
        if (a.error != null) ...[
          const SizedBox(height: 12),
          AppNotice(message: context.tr(a.error!), tone: NoticeTone.warning)
        ],
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
            onPressed: _busy || a.busy || a.conflict != null
                ? null
                : () => _run(a.sync),
            icon: const Icon(Icons.sync_rounded, size: 19),
            label: Text(context.tr('Sync now'))),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 4),
            title: Text(context.tr('About cloud sync'),
                style: const TextStyle(fontSize: 12)),
            children: [
              Text(
                  context.tr(
                      'Your garden saves automatically while you use the app. Your music stays on this phone.'),
                  style: const TextStyle(
                      fontSize: 13, height: 1.5, color: Color(0xFFADC3BE)))
            ]),
      ])),
      if (a.conflict != null) ...[
        const SizedBox(height: 16),
        AccountPanel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(context.tr('Choose a garden version'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                  context.tr(
                      'Both garden versions are preserved. Choose the version you want to keep. Water and XP will not be added together.'),
                  style: const TextStyle(
                      fontSize: 13, height: 1.5, color: Color(0xFFADC3BE))),
              const SizedBox(height: 14),
              Text(
                  context.tr('This device: {p0} XP · Cloud: {p1} XP', {
                    'p0': ((a.currentGarden?['progress'] as Map?)?['xp']) ?? 0,
                    'p1': ((a.conflict?['snapshot'] as Map?)?['progress']
                            as Map?)?['xp'] ??
                        0,
                  }),
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 14),
              FilledButton(
                  onPressed:
                      _busy || a.busy ? null : () => _resolveConflict(true),
                  child: Text(context.tr('Use cloud garden'))),
              OutlinedButton(
                  onPressed:
                      _busy || a.busy ? null : () => _resolveConflict(false),
                  child: Text(context.tr('Keep this device’s garden'))),
            ])),
      ],
      if (a.recoveryCopy != null)
        TextButton.icon(
            icon: const Icon(Icons.save_alt_rounded, size: 18),
            onPressed: _busy
                ? null
                : () => _run(() async {
                      final saved = await LocalBackupFiles.saveJson(
                          contents: jsonEncode(a.recoveryCopy),
                          suggestedName: 'BetterSeed-sync-recovery.json');
                      if (mounted && saved)
                        ScaffoldMessenger.of(context).showSnackBar(AppToast(
                            tone: NoticeTone.success,
                            content: Text(context.tr(
                                'Backup saved. Keep this file somewhere safe.'))));
                    }),
            label: Text(context.tr('Save a copy of both gardens'))),
      const SizedBox(height: 24),
      Text(context.tr('Security'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      AccountPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Column(children: [
            AccountActionTile(
                icon: Icons.shield_outlined,
                title: context.tr('Authenticator'),
                subtitle: context.tr(enabled
                    ? 'Two-factor authentication is on'
                    : 'Protect your account with an authenticator'),
                onTap: _busy
                    ? null
                    : enabled
                        ? _disableFactor
                        : _setupFactor),
            if (!google) ...[
              const Divider(height: 1),
              AccountActionTile(
                  icon: Icons.lock_outline_rounded,
                  title: context.tr('Change password'),
                  onTap: _busy ? null : _changePassword)
            ],
          ])),
      const SizedBox(height: 20),
      OutlinedButton.icon(
          onPressed: _busy ? null : _signOut,
          icon: const Icon(Icons.logout_rounded, size: 19),
          label: Text(context.tr('Sign out'))),
      const SizedBox(height: 12),
      AccountActionTile(
          icon: Icons.delete_outline_rounded,
          danger: true,
          title: context.tr('Delete account permanently'),
          subtitle:
              context.tr('Review what will be removed before confirming.'),
          onTap: _busy ? null : _delete),
    ];
  }
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
  final _errors = <String, String>{};
  final _visible = <String>{};

  void _submit() {
    _errors.clear();
    for (final entry in controllers.entries) {
      final value = entry.value.text;
      if (entry.key == 'confirmation' && value != 'DELETE') {
        _errors[entry.key] = 'Type DELETE to confirm';
      } else if (entry.key == 'newPassword' &&
          (value.length < 12 || value.length > 128)) {
        _errors[entry.key] = 'Use 12–128 characters for your password.';
      } else if (value.trim().isEmpty) {
        _errors[entry.key] = entry.key == 'factor'
            ? 'Enter your verification code.'
            : 'Enter your password.';
      }
    }
    if (_errors.isNotEmpty) {
      setState(() {});
      return;
    }
    Navigator.pop(context, {
      for (final e in controllers.entries)
        e.key: e.key == 'factor' ? e.value.text.trim() : e.value.text
    });
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
        icon: widget.fields.containsKey('confirmation')
            ? Icons.delete_outline_rounded
            : Icons.lock_outline_rounded,
        tone: widget.fields.containsKey('confirmation')
            ? NoticeTone.error
            : NoticeTone.info,
        title: Text(widget.title),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.tr(widget.description)),
          const SizedBox(height: 16),
          ...widget.fields.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: controllers[e.key],
                obscureText: e.key.toLowerCase().contains('password') &&
                    !_visible.contains(e.key),
                maxLength: e.key.toLowerCase().contains('password') ? 128 : 254,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                    labelText: context
                        .tr(e.key == 'factor' ? 'Verification code' : e.value),
                    helperText: e.key == 'newPassword'
                        ? context.tr('12–128 characters')
                        : e.key == 'factor'
                            ? context.tr('Authenticator or recovery code')
                            : null,
                    helperMaxLines: 3,
                    counterText: '',
                    errorText: _errors[e.key] == null
                        ? null
                        : context.tr(_errors[e.key]!),
                    suffixIcon: e.key.toLowerCase().contains('password')
                        ? IconButton(
                            tooltip: context.tr(_visible.contains(e.key)
                                ? 'Hide password'
                                : 'Show password'),
                            onPressed: () => setState(() {
                              if (!_visible.add(e.key)) _visible.remove(e.key);
                            }),
                            icon: Icon(_visible.contains(e.key)
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                          )
                        : null),
              ))),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr("Cancel"))),
          FilledButton(
              onPressed: _submit, child: Text(context.tr(widget.action)))
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
    if (_busy) return;
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(
          () => _error = 'Enter the 6-digit code from your authenticator.');
      return;
    }
    FocusScope.of(context).unfocus();
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
          appBar: AppBar(title: Text(context.tr("Set up authenticator"))),
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_recovery == null) ...[
                        Text(context.tr(
                            "Scan this QR code in Google Authenticator, Aegis, or another TOTP app. Setup expires after 10 minutes.")),
                        const SizedBox(height: 20),
                        Center(
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: QrImageView(
                                    data: widget.setup['uri'] as String,
                                    size: 220,
                                    backgroundColor: Colors.white))),
                        const SizedBox(height: 16),
                        ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(context.tr('Cannot scan the QR code?'),
                                style: const TextStyle(fontSize: 13)),
                            children: [
                              AccountPanel(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(context.tr(
                                            'Or enter this secret manually:')),
                                        const SizedBox(height: 10),
                                        SelectableText(
                                            widget.setup['secret'] as String,
                                            style: const TextStyle(
                                                fontFamily: 'monospace',
                                                height: 1.5)),
                                      ]))
                            ]),
                        const SizedBox(height: 20),
                        TextField(
                            controller: _code,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText:
                                    context.tr("6-digit authenticator code"),
                                border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _busy ? null : _confirm,
                            child: Text(context
                                .tr("Enable two-factor authentication"))),
                      ] else ...[
                        Text(context.tr("Save your recovery codes"),
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 16),
                        Text(context.tr(
                            "Each code can be used once if you lose your authenticator. They are shown only now. Store them somewhere safe outside this phone.")),
                        const SizedBox(height: 16),
                        AccountPanel(
                            child: SelectableText(_recovery!.join('\n'),
                                style: const TextStyle(
                                    fontFamily: 'monospace', height: 1.8))),
                        CheckboxListTile(
                            value: _saved,
                            onChanged: (v) =>
                                setState(() => _saved = v ?? false),
                            title: Text(context
                                .tr("I saved my recovery codes safely"))),
                        FilledButton(
                            onPressed:
                                _saved ? () => Navigator.pop(context) : null,
                            child: Text(context.tr("Done"))),
                      ],
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: AppNotice(
                                message: context.tr(_error!),
                                tone: NoticeTone.error)),
                    ]),
              ))),
        ),
      );
}
