// Abre o Chrome do perfil persistente do addon para login manual no RuTracker.
// Uso: node open-login.mjs
import { chromium } from "playwright-core";
import * as os from "os";
import * as path from "path";
import "dotenv/config";

const RUTRACKER_BASE = process.env.RUTRACKER_BASE || "https://rutracker.org/forum";
const PROFILE_DIR =
  process.env.RUTRACKER_PROFILE_DIR ||
  path.join(os.homedir(), ".rutracker-addon", "chrome-profile");

// Usa o Google Chrome instalado no PC; se não existir, usa o Chromium do Playwright.
// As flags escondem o modo automatizado (necessário para o Cloudflare aceitar).
const opts = {
  headless: false,
  viewport: null,
  ignoreDefaultArgs: ["--enable-automation"],
  args: ["--disable-blink-features=AutomationControlled", "--start-maximized"],
};
let ctx;
try {
  ctx = await chromium.launchPersistentContext(PROFILE_DIR, {
    ...opts,
    channel: "chrome",
  });
} catch {
  ctx = await chromium.launchPersistentContext(PROFILE_DIR, opts);
}

const page = await ctx.newPage();
console.log("A abrir:", `${RUTRACKER_BASE}/login.php`);
console.log("Entra na tua conta na janela do Chrome. Mantém a janela aberta —");
console.log("o addon reutiliza esta sessão. Fecha quando terminares.");

await page.goto(`${RUTRACKER_BASE}/login.php`, { waitUntil: "domcontentloaded", timeout: 60000 });
await page.waitForTimeout(1000);

const close = async () => {
  try {
    await ctx.close();
  } catch {}
  process.exit(0);
};
process.on("SIGINT", close);
process.on("SIGTERM", close);