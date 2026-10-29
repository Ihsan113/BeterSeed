import { GoogleAuth, OAuth2Client } from "google-auth-library";
import type { Config } from "./config.js";
import { fail } from "./security.js";
export interface GoogleIdentity {
  sub: string;
  email: string;
}
export interface PlayPurchase {
  purchaseState: number;
  consumptionState: number;
  obfuscatedExternalAccountId?: string;
  quantity?: number;
}
export interface Providers {
  googleIdentity(idToken: string): Promise<GoogleIdentity>;
  playPurchase(product: string, token: string): Promise<PlayPurchase>;
  consume(product: string, token: string): Promise<void>;
  voided(page?: string): Promise<{ tokens: string[]; next?: string }>;
  verifyNotification(bearer: string): Promise<void>;
  sendMail(payload: {
    to: string;
    subject: string;
    html: string;
  }): Promise<void>;
}
export function providers(c: Config): Providers {
  const oauth = new OAuth2Client();
  const play = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const productUrl = (product: string, token: string) =>
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${c.GOOGLE_PLAY_PACKAGE_NAME}/purchases/products/${encodeURIComponent(product)}/tokens/${encodeURIComponent(token)}`;
  return {
    async googleIdentity(idToken) {
      if (!c.GOOGLE_WEB_CLIENT_ID) fail(503, "google_unavailable");
      try {
        const ticket = await oauth.verifyIdToken({
          idToken,
          audience: c.GOOGLE_WEB_CLIENT_ID,
        });
        const p = ticket.getPayload();
        if (
          !p?.sub ||
          !p.email ||
          p.email_verified !== true ||
          !p.iat ||
          Date.now() / 1000 - p.iat > 600
        )
          fail(401, "invalid_google_identity");
        return { sub: p!.sub!, email: p!.email!.toLowerCase() };
      } catch {
        return fail(401, "invalid_google_identity");
      }
    },
    async playPurchase(product, token) {
      const client = await play.getClient();
      const r = await client.request<PlayPurchase>({
        url: productUrl(product, token),
        timeout: 15000,
        retry: false,
      });
      return r.data;
    },
    async consume(product, token) {
      const client = await play.getClient();
      await client.request({
        method: "POST",
        url: productUrl(product, token) + ":consume",
        timeout: 15000,
        retry: false,
      });
    },
    async voided(page) {
      const client = await play.getClient();
      const r = await client.request<any>({
        url: `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${c.GOOGLE_PLAY_PACKAGE_NAME}/purchases/voidedpurchases`,
        params: {
          startTime: Date.now() - 30 * 86400000,
          maxResults: 1000,
          ...(page ? { token: page } : {}),
        },
        timeout: 15000,
      });
      return {
        tokens: (r.data.voidedPurchases ?? []).map((x: any) => x.purchaseToken),
        next: r.data.tokenPagination?.nextPageToken,
      };
    },
    async verifyNotification(bearer) {
      if (!c.GOOGLE_RTDN_AUDIENCE || !c.GOOGLE_RTDN_SERVICE_ACCOUNT_EMAIL)
        fail(503, "notifications_unavailable");
      try {
        const t = await oauth.verifyIdToken({
          idToken: bearer,
          audience: c.GOOGLE_RTDN_AUDIENCE,
        });
        const p = t.getPayload();
        if (
          p?.email !== c.GOOGLE_RTDN_SERVICE_ACCOUNT_EMAIL ||
          p.email_verified !== true
        )
          fail(401, "invalid_notification");
      } catch {
        fail(401, "invalid_notification");
      }
    },
    async sendMail(payload) {
      if (!c.GMAIL_RELAY_API_KEY) fail(503, "email_unavailable");
      const r = await fetch(
        c.GMAIL_RELAY_BASE_URL.replace(/\/$/, "") + "/api/send",
        {
          method: "POST",
          headers: {
            "X-API-Key": c.GMAIL_RELAY_API_KEY,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            ...payload,
            ...(c.SUPPORT_EMAIL ? { reply_to: c.SUPPORT_EMAIL } : {}),
          }),
          signal: AbortSignal.timeout(15000),
          redirect: "error",
        },
      );
      if (!r.ok) throw Error("Email delivery failed");
    },
  };
}
