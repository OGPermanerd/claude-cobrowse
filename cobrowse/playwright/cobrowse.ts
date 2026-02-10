/**
 * cobrowse.ts - Interruption-aware Playwright CDP wrapper
 *
 * Detects when a human intervenes via noVNC during automated browser actions
 * and returns structured results instead of throwing.
 *
 * Two main methods:
 *   session.do()    - Run an action; catch errors caused by human intervention
 *   session.watch() - Wait for the human to do something (navigation, click, etc.)
 */

import { chromium, type Page, type Browser, type Frame } from "playwright";

export type InterruptReason =
  | "navigation"
  | "dom_change"
  | "element_detached"
  | "context_destroyed"
  | "target_closed";

export interface ActionResult<T = void> {
  /** Whether the action completed and its return value is usable */
  ok: boolean;
  /** Whether human intervention was detected */
  interrupted: boolean;
  /** Classification of what happened */
  reason?: InterruptReason;
  /** URL before the action started */
  previousUrl?: string;
  /** URL after interruption was detected */
  currentUrl?: string;
  /** Return value from the action (when ok=true) */
  value?: T;
  /** Error message if action threw */
  error?: string;
}

const INTERRUPT_PATTERNS: Array<[RegExp, InterruptReason]> = [
  [/navigat/i, "navigation"],
  [/detached|disposed/i, "element_detached"],
  [/execution context|context was destroyed/i, "context_destroyed"],
  [/target closed|target page|page has been closed/i, "target_closed"],
];

export class CobrowseSession {
  readonly page: Page;
  readonly browser: Browser;

  constructor(browser: Browser, page: Page) {
    this.browser = browser;
    this.page = page;
  }

  /** Connect to the persistent Chrome instance via CDP */
  static async connect(
    cdpUrl = "http://localhost:9222"
  ): Promise<CobrowseSession> {
    const browser = await chromium.connectOverCDP(cdpUrl);
    const context = browser.contexts()[0];
    if (!context)
      throw new Error("No browser context found - is Chrome running?");
    const page = context.pages()[0] || (await context.newPage());
    return new CobrowseSession(browser, page);
  }

  /**
   * Execute an automation action with interruption detection.
   *
   * If the action throws due to human intervention (navigating away,
   * clicking something that changes the DOM, etc.), returns
   * { interrupted: true } with details instead of throwing.
   *
   * Safe to use with page.goto() - won't false-positive on your own navigations.
   *
   *   const r = await session.do(async (page) => {
   *     await page.goto("https://example.com");
   *     return page.title();
   *   });
   *   if (r.interrupted) console.log("Human took over!");
   */
  async do<T>(fn: (page: Page) => Promise<T>): Promise<ActionResult<T>> {
    const urlBefore = this.page.url();

    try {
      const value = await fn(this.page);

      // Action succeeded. Check if the page ended up somewhere unexpected.
      // This catches cases where human navigated concurrently but the action
      // still completed (e.g., reading a value just before navigation).
      return { ok: true, interrupted: false, value };
    } catch (err: any) {
      // Action failed. Was it because of human intervention?
      const currentUrl = safeUrl(this.page);
      const reason = classifyError(err);

      if (reason) {
        this._emit(reason, urlBefore, currentUrl);
        return {
          ok: false,
          interrupted: true,
          reason,
          previousUrl: urlBefore,
          currentUrl,
          error: err.message,
        };
      }

      // Fallback: if the URL changed, the error was likely caused by
      // human navigation even if the error message is generic (e.g.,
      // Playwright's auto-wait timeout after the page navigated away).
      if (currentUrl !== urlBefore && currentUrl !== "(unknown)") {
        this._emit("navigation", urlBefore, currentUrl);
        return {
          ok: false,
          interrupted: true,
          reason: "navigation",
          previousUrl: urlBefore,
          currentUrl,
          error: err.message,
        };
      }

      // Not an interruption - propagate the real error
      throw err;
    }
  }

  /**
   * Wait for the human to take an action (navigate, etc.).
   *
   * Returns as soon as the main frame navigates to a different URL,
   * or after the timeout expires. Use this when you want the human
   * to do something in the browser.
   *
   *   console.log("Please log in via the browser...");
   *   const r = await session.watch({ timeout: 30000 });
   *   if (r.interrupted) {
   *     console.log(`User navigated to ${r.currentUrl}`);
   *   }
   */
  async watch(opts?: {
    /** Max time to wait in ms (default: 30000) */
    timeout?: number;
    /** Optional: only trigger on URLs matching this pattern */
    urlPattern?: RegExp;
    /** Optional: CSS selector - triggers when a matching element appears in the DOM */
    selector?: string;
    /** Optional: triggers when any element matching this selector is clicked */
    clickSelector?: string;
  }): Promise<ActionResult<void>> {
    const timeout = opts?.timeout ?? 30_000;
    const urlBefore = this.page.url();

    return new Promise<ActionResult<void>>((resolve) => {
      let done = false;
      let pollTimer: ReturnType<typeof setInterval> | null = null;

      const finish = (result: ActionResult<void>) => {
        if (done) return;
        done = true;
        cleanup();
        resolve(result);
      };

      // 1. Navigation detection (always active)
      const onNav = (frame: Frame) => {
        if (done || frame !== this.page.mainFrame()) return;
        const newUrl = frame.url();
        if (newUrl === urlBefore) return;
        if (opts?.urlPattern && !opts.urlPattern.test(newUrl)) return;

        this._emit("navigation", urlBefore, newUrl);
        finish({
          ok: true,
          interrupted: true,
          reason: "navigation",
          previousUrl: urlBefore,
          currentUrl: newUrl,
        });
      };
      this.page.on("framenavigated", onNav);

      // 2. DOM selector detection - poll for element appearance
      if (opts?.selector) {
        pollTimer = setInterval(async () => {
          if (done) return;
          try {
            const visible = await this.page
              .locator(opts.selector!)
              .first()
              .isVisible({ timeout: 100 })
              .catch(() => false);
            if (visible) {
              this._emit("dom_change", urlBefore, `selector: ${opts.selector}`);
              finish({
                ok: true,
                interrupted: true,
                reason: "dom_change",
                previousUrl: urlBefore,
                currentUrl: safeUrl(this.page),
              });
            }
          } catch { /* page may be transitioning */ }
        }, 300);
      }

      // 3. Click detection - inject a click listener via page.evaluate
      if (opts?.clickSelector) {
        this.page
          .evaluate(
            (sel: string) => {
              return new Promise<string>((resolve) => {
                const handler = (e: Event) => {
                  const target = (e.target as Element)?.closest(sel);
                  if (target) {
                    document.removeEventListener("click", handler, true);
                    resolve(target.textContent?.trim().substring(0, 200) || "(clicked)");
                  }
                };
                document.addEventListener("click", handler, true);
              });
            },
            opts.clickSelector
          )
          .then((clickedText) => {
            if (!done) {
              this._emit("dom_change", urlBefore, `click: ${clickedText}`);
              finish({
                ok: true,
                interrupted: true,
                reason: "dom_change",
                previousUrl: urlBefore,
                currentUrl: safeUrl(this.page),
                value: clickedText as any,
              });
            }
          })
          .catch(() => { /* page closed or navigated */ });
      }

      // 4. Timeout
      const timer = setTimeout(() => {
        finish({
          ok: true,
          interrupted: false,
          previousUrl: urlBefore,
          currentUrl: safeUrl(this.page),
        });
      }, timeout);

      const cleanup = () => {
        this.page.off("framenavigated", onNav);
        clearTimeout(timer);
        if (pollTimer) clearInterval(pollTimer);
      };
    });
  }

  /** Get current page URL */
  url(): string {
    return this.page.url();
  }

  /** Disconnect from CDP (does NOT close Chrome) */
  async disconnect(): Promise<void> {
    await this.browser.close();
  }

  private _emit(reason: string, from: string, to: string) {
    console.log(`[COBROWSE] Human intervened: ${reason} (${from} -> ${to})`);
  }
}

function classifyError(err: any): InterruptReason | null {
  const msg = err.message || "";
  for (const [pattern, reason] of INTERRUPT_PATTERNS) {
    if (pattern.test(msg)) return reason;
  }
  return null;
}

function safeUrl(page: Page): string {
  try {
    return page.url();
  } catch {
    return "(unknown)";
  }
}
