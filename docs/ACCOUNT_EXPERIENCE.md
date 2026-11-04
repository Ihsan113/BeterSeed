# Account experience — app 1.8.1+60 / server 1.3.1

Base runtime: GitHub main `a1aa3bd` and the user's November 4 VPS-guards source ZIP. This source update is not a production deployment. Preserve the native systemd/MySQL topology and follow `AGENTS.md` and `server/UPGRADE.md` before any separately authorized VPS work.

## User-facing changes

- Account identity, cloud sync and security have separate compact surfaces. Extra sync explanation opens on demand. Sync conflicts still preserve both versions and now require confirmation before selecting a version.
- Existing email verification begins with email/password, policies and **Send verification code**. Only a successful request opens the code field. Resending has a 60-second UI cooldown; server limits remain authoritative. A failed or expired code leaves the user on the same step with retry guidance.
- Correct credentials allow explicit already-verified status and send the user back to sign-in. Public registration with unknown/wrong credentials remains generic to prevent account enumeration. A verified status is not a login session and cannot bypass 2FA.
- Login, signup, email verification and recovery show only the controls relevant to the current step. Email-password reset still requires the enrolled authenticator or recovery code after email proof; Google accounts still hide password controls.
- Confirmation dialogs and floating notifications share a custom style. Destructive actions use a clear destructive appearance; identity forms validate before closing. Dialog content scrolls when the keyboard or large text reduces available space.
- Garden edit and focus are accessible icon buttons with localized tooltips and 48-pixel touch targets. Their layout is separate from the motivational message; saved tree positions and scene geometry are unchanged.
- New text is translated into all seven supported languages. Leaf Coins naming is preserved.

## Backend compatibility

Deploy backend 1.3.1 before the new APK. The new route is `POST /v1/auth/verification/start` with `{email, password}`. Correct credentials return `{status: "already_verified"}` or `{status: "verification_sent", challengeId}`. Unknown emails, wrong passwords and Google-only accounts return the same `invalid_credentials` error. Correct-password login for an unverified email returns `email_not_verified`.

The register endpoint keeps `challengeId` for old clients and optionally returns `status: "already_verified"` after password proof. No schema changes, environment changes, new billing settings or production migrations were introduced by this update. The older resend and reset endpoints remain available for existing apps.

## Verification

Automated coverage includes request-before-code, resend cooldown, expired/invalid OTP, already-verified feedback, invalid inputs, deletion confirmation, compact large-text dialogs, seven-language layouts and Garden HUD overlap. Backend integration tests use the isolated local MySQL fixture and cover status privacy, OTP single use, suspension/rate limits, sync, billing and 2FA reset protection. Never point the fixture tests at production.

Before rollout, verify the configured API on a staging installation, real email delivery, Google sign-in and Android text scaling/keyboard behavior. Mocked local provider tests do not prove production delivery or Google/Play configuration. No production state has been verified by this UI task.
