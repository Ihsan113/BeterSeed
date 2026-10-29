import { z } from "zod";
const envSchema = z.object({
  NODE_ENV: z.enum(["production", "development", "test"]).default("production"),
  HOST: z.string().default("127.0.0.1"),
  PORT: z.coerce.number().int().min(1).max(65535).default(8080),
  PUBLIC_BASE_URL: z.url().default("https://localhost"),
  TRUST_PROXY: z.string().default(""),
  MYSQL_HOST: z.string().default("127.0.0.1"),
  MYSQL_PORT: z.coerce.number().default(3306),
  MYSQL_DATABASE: z.string().default("betterseed"),
  MYSQL_USER: z.string().default("betterseed"),
  MYSQL_PASSWORD: z.string().min(1),
  TOKEN_PEPPER: z.string().regex(/^[0-9a-f]{64}$/i),
  DATA_ENCRYPTION_KEY: z.string().regex(/^[0-9a-f]{64}$/i),
  GOOGLE_WEB_CLIENT_ID: z.string().default(""),
  GOOGLE_PLAY_PACKAGE_NAME: z
    .literal("com.betterseed.app")
    .default("com.betterseed.app"),
  GOOGLE_APPLICATION_CREDENTIALS: z.string().default(""),
  GOOGLE_RTDN_AUDIENCE: z.string().default(""),
  GOOGLE_RTDN_SERVICE_ACCOUNT_EMAIL: z.string().default(""),
  GMAIL_RELAY_BASE_URL: z.url().default("https://gmailrelay.vercel.app"),
  GMAIL_RELAY_API_KEY: z.string().default(""),
  LEGAL_OPERATOR_NAME: z.string().default(""),
  SUPPORT_EMAIL: z.string().default(""),
  LEGAL_VERSION: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .default("2026-10-28"),
});
export type Config = z.infer<typeof envSchema>;
export function configFromEnv(env = process.env): Config {
  const c = envSchema.parse(env);
  if (c.NODE_ENV === "production") {
    if (
      !c.PUBLIC_BASE_URL.startsWith("https://") ||
      !c.GMAIL_RELAY_BASE_URL.startsWith("https://")
    )
      throw Error("HTTPS is required");
    if (
      !c.LEGAL_OPERATOR_NAME.trim() ||
      !z.email().safeParse(c.SUPPORT_EMAIL).success
    )
      throw Error("Configure legal operator and support email before launch");
    if (!c.GMAIL_RELAY_API_KEY)
      throw Error("Configure the email relay before launch");
    if (c.TOKEN_PEPPER === c.DATA_ENCRYPTION_KEY)
      throw Error("Use independent secrets");
  }
  return c;
}
