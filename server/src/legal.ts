import type { FastifyInstance } from "fastify";
import type { Config } from "./config.js";
export function legalDocuments(c: Config) {
  const operator =
    c.LEGAL_OPERATOR_NAME || "BetterSeed operator (not configured)";
  const contact = c.SUPPORT_EMAIL || "Support contact is not configured";
  return {
    version: c.LEGAL_VERSION,
    operator,
    contact,
    documents: {
      privacy: {
        title: "Privacy policy",
        body: `BetterSeed is operated by ${operator}. Contact: ${contact}.

Guest use: your garden stays on your device. Android may back up app preferences according to your device settings. Manual exports are controlled by you.

Account data: for email accounts we store your email, a password hash, and verification status. For Google accounts we store your Google identifier and email; we do not receive your Google password or request Drive access. We store accepted terms version, login sessions, encrypted authenticator secrets, hashed recovery codes, and temporary verification challenges to secure your account.

Cloud sync: while signed in, BetterSeed uploads habits and titles, completion history, water and tree progress, garden appearance and placement, and selected sound/motion preferences. Avoid putting sensitive personal information in habit titles. Local MP3 files, notification permission, and wallpaper images are not uploaded. Sync occurs while the app is active and connected. Conflicting device versions require your choice.

Purchases: Google Play processes payments. Our server verifies purchase tokens with Google and stores coin transactions and unlocked packs. We do not receive payment-card details. Purchase information cannot be edited through garden backup or sync.

Service providers: our hosting provider stores the MySQL database. Google provides sign-in and payment services. Verification and password-reset email is sent through Gmail Relay (gmailrelay.vercel.app) and Gmail; the relay receives your destination email and message, including the time-limited code. These services may process data outside your country. No advertising or analytics SDK is added by this account system.

Retention: account and synced garden data remain until you delete your account. Email codes expire after 10 minutes; login challenges after 5 minutes. Undelivered messages are removed when expired; completed messages are removed immediately. Rate-limit identifiers are keyed hashes and expire after their window. Expired sessions and challenges are cleaned by a maintenance worker. Unverified new registrations older than 7 days are removed. Existing accounts awaiting verification of a changed email retain their data. Authorized support administrators can review account status and progress totals, correct email addresses, manage access and resolve coin or pack issues. Administrative actions are recorded for up to 180 days; account-linked notes are removed on account deletion. Administrators cannot view passwords or authenticator secrets through the dashboard. Database backups are retained for at most 30 days under the deployment policy.

Deletion: Settings → Account & sync → Delete account permanently removes account identity, cloud garden, sessions, authenticator data, and entitlements from the active database. A keyed anonymous purchase fingerprint and financial deltas remain to prevent duplicate delivery/fraud; these contain no email or Google identifier. Deleting an account does not issue a Google Play refund. You may also request deletion using the support email above and the public /delete-account page; identity verification is required. Device exports and Google-managed purchase records are outside our control. Other offline devices may retain downloaded progress or local recovery copies. Clear app data or uninstall on those devices to erase those local copies; deleted accounts cannot sync them back.

Your choices: use guest mode, export your garden, sign out, manage two-factor authentication, or delete your account. Contact us to request access or correction. We do not knowingly collect account information from children under 13 (or a higher local minimum age). Ask a guardian for help if applicable.

We use HTTPS, server-side authorization, password hashing, encrypted secrets, and limited retention. No service can promise absolute security. Changes to this policy are published here with a new version.`,
      },
      terms: {
        title: "Terms of use",
        body: `These terms apply to BetterSeed, provided by ${operator}. Contact: ${contact}. Version: ${c.LEGAL_VERSION}.

You must meet the applicable minimum age for an online account (at least 13) and provide accurate account information. Keep your password, authenticator, and recovery codes private. Do not abuse email delivery, bypass purchase verification, or disrupt the service.

BetterSeed supports personal habit tracking and relaxation. It is not medical advice or a guarantee of health, productivity, or financial results.

Guest data stays on your device and is not automatically uploaded. Account sync needs connectivity. When two devices change the same saved version, you choose which version to keep; the app preserves a local recovery copy. Export important data before changing devices. Local audio and device permissions are not synced.

Leaf Coins are virtual credits usable only in BetterSeed. Purchase prices are shown by Google Play. Coins are added after payment confirmation and linked to your BetterSeed account. Sign in to the same account to see your balance and unlocked packs on another device. Do not buy while signed in to someone else's account. Refunds and chargebacks remove the corresponding coins; spending refunded coins may leave a negative balance and block further unlocks until covered. Existing pack unlocks are not automatically resold or transferable. Google Play refund policies and mandatory consumer rights apply.

Deleting your account removes cloud progress and access to its coin balance and packs. It does not cancel or refund previous purchases. Export first if you want a personal copy. Support can investigate purchase problems using an order reference; never send passwords or recovery codes.

You retain rights to your own habit content and grant the permissions needed to store and sync it. The app and its artwork remain subject to their respective licenses. Bundled music is used under the stated music license, not transferred to you for standalone resale.

We may suspend access for proven abuse, fraud, or legal requirements. Service availability and features may change. Liability limitations apply only where lawful; these terms do not remove statutory consumer rights. Contact support to resolve issues. Material policy changes will be published with a new version.`,
      },
      licenses: {
        title: "Licenses & music credits",
        body: `BetterSeed includes third-party open-source packages. In the app, open “Open-source licenses” for their notices.

Music in BetterSeed:
Piano in the Forest — Pixabay track #308945
https://pixabay.com/music/modern-classical-piano-in-the-forest-308945/
Pixabay Content License: https://pixabay.com/service/license-summary/
Full terms: https://pixabay.com/service/terms/

“Royalty-free” does not mean public domain or copyright-free. Pixabay's license allows covered uses subject to its conditions, including restrictions on standalone redistribution/resale and other prohibited uses. The original creator retains their rights.

Imported MP3 files remain on your device. You are responsible for permission to use music you import. Artwork and branding are not automatically covered by the Pixabay music license.`,
      },
      faq: {
        title: "Frequently asked questions",
        body: `Can I use BetterSeed without an account?
Yes. Choose Continue as guest. Habits and gardening work offline. Cloud sync and new purchases require an account.

What is synced?
Habits, completion history, water and tree progress, garden layout and selected preferences. Your coin balance and unlocked packs stay with your account. Music files and phone permissions stay on each device.

What if two phones change my garden?
Neither version silently overwrites the other. Account & sync shows a conflict. Choose the cloud version or this device's version; export the recovery copy if you want to retain both. Your water and XP follow the garden version you choose.

How do I recover my account?
Email users can request a reset code from Forgot password. Google users sign in with Google and manage their Google password with Google. If two-factor authentication is enabled, an authenticator or an unused recovery code is also required. Store recovery codes safely; support cannot disclose your secret.

Where are my purchased coins?
Sign in to the same BetterSeed account, open the coin store and retry pending delivery. The server verifies Google Play purchases before granting coins. A consumed purchase is not granted a second time by Restore. If a charge is pending, wait for Google Play to complete it. For older versions that stored coins only on-device, keep the old data/export and contact support with your Play order reference; local balances cannot be trusted as payment proof.

Can I delete my account?
Yes, in Account & sync. Re-enter your password or sign in with Google again and provide an authenticator/recovery code if enabled. This action is permanent and does not create a refund.

Does wallpaper update automatically?
No. The wallpaper is a still image. Set it again after your tree grows.`,
      },
      about: {
        title: "About BetterSeed",
        body: `BetterSeed turns small daily habits into a growing garden. Track routines, earn water, care for your tree, and personalize a calm space.

Operated by ${operator}.
Support: ${contact}
Account API and policy version: ${c.LEGAL_VERSION}

Built with Flutter. Payments use Google Play Billing. Cloud accounts are optional.`,
      },
    },
  };
}
export function legalRoutes(app: FastifyInstance, c: Config) {
  app.get("/v1/legal", async () => legalDocuments(c));
  const escape = (s: string) =>
    s.replace(
      /[&<>"']/g,
      (x) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[x]!,
    );
  for (const key of ["privacy", "terms", "licenses", "faq", "about"] as const) {
    app.get("/" + key, async (_r, reply) => {
      const d = legalDocuments(c).documents[key];
      return reply.type("text/html; charset=utf-8").send(
        `<!doctype html><html lang="en"><meta name="viewport" content="width=device-width"><title>${escape(d.title)} · BetterSeed</title><body><main><h1>${escape(d.title)}</h1><p>Version ${escape(c.LEGAL_VERSION)}</p>${d.body
          .split("\n\n")
          .map((p) => `<p>${escape(p).replace(/\n/g, "<br>")}</p>`)
          .join(
            "",
          )}<p><a href="/privacy">Privacy</a> · <a href="/terms">Terms</a> · <a href="/delete-account">Delete account</a></p></main></body></html>`,
      );
    });
  }
  app.get("/delete-account", async (_r, reply) =>
    reply
      .type("text/html; charset=utf-8")
      .send(
        `<!doctype html><html lang="en"><meta name="viewport" content="width=device-width"><title>Delete BetterSeed account</title><body><main><h1>Delete your BetterSeed account</h1><p>In BetterSeed, open Settings → Account &amp; sync → Delete account permanently. Reauthenticate and confirm DELETE. This removes your account, cloud garden, sessions, and purchased entitlements from the active database. It does not issue a refund.</p><p>If you cannot use the app, send an account-deletion request from your registered email to <a href="mailto:${escape(c.SUPPORT_EMAIL)}?subject=BetterSeed%20account%20deletion">${escape(c.SUPPORT_EMAIL)}</a>. We will verify ownership before deleting. Never send your password or authenticator codes.</p><p>Anonymous anti-replay purchase fingerprints and financial deltas are retained for fraud prevention. Backups expire within 30 days. Other offline devices may retain local copies; clear app data on those devices to erase them. See our <a href="/privacy">privacy policy</a>.</p></main></body></html>`,
      ),
  );
}
