#!/usr/bin/env npx tsx
/**
 * test-interruption.ts - Automated test for interruption detection
 *
 * Simulates human intervention by using a second CDP reference to
 * navigate the page while a slow action is running.
 *
 * Usage: npx tsx test-interruption.ts
 */

import { chromium } from "playwright";
import { CobrowseSession } from "./cobrowse.js";

let passed = 0;
let failed = 0;

function assert(condition: boolean, msg: string) {
  if (condition) {
    console.log(`  PASS: ${msg}`);
    passed++;
  } else {
    console.log(`  FAIL: ${msg}`);
    failed++;
  }
}

async function main() {
  console.log("Connecting to Chrome via CDP...\n");
  const session = await CobrowseSession.connect();

  // Second CDP connection to simulate human actions
  const humanBrowser = await chromium.connectOverCDP("http://localhost:9222");
  const humanPage = humanBrowser.contexts()[0].pages()[0];

  // --- Test 1: do() completes normally ---
  console.log("Test 1: do() - normal completion");
  await session.page.goto("https://example.com", { waitUntil: "domcontentloaded" });
  const r1 = await session.do(async (page) => {
    return page.title();
  });
  assert(r1.ok === true, "ok is true");
  assert(r1.interrupted === false, "not interrupted");
  assert(r1.value === "Example Domain", `title is "${r1.value}"`);
  console.log();

  // --- Test 2: do() with goto (should NOT false-positive) ---
  console.log("Test 2: do() - own navigation via goto");
  const r2 = await session.do(async (page) => {
    await page.goto("https://news.ycombinator.com", { waitUntil: "domcontentloaded" });
    return page.title();
  });
  assert(r2.ok === true, "ok is true");
  assert(r2.interrupted === false, "not interrupted (own goto)");
  assert(r2.value === "Hacker News", `title is "${r2.value}"`);
  console.log();

  // --- Test 3: do() interrupted by "human" navigation ---
  console.log("Test 3: do() - interrupted by human navigation");
  const r3 = await session.do(async (page) => {
    // Start a slow operation
    const items = page.locator(".titleline > a");
    const count = await items.count();

    // After a short delay, "human" navigates away
    setTimeout(() => {
      humanPage.goto("https://example.com").catch(() => {});
    }, 300);

    // Try to read all items slowly - should fail mid-way.
    // Short timeout so we detect the interruption quickly (not 30s default).
    const links: string[] = [];
    for (let i = 0; i < count; i++) {
      const text = await items.nth(i).textContent({ timeout: 2000 });
      links.push(text || "");
      await page.waitForTimeout(200);
    }
    return links;
  });
  assert(r3.interrupted === true, "detected interruption");
  assert(r3.reason !== undefined, `reason: ${r3.reason}`);
  assert(r3.ok === false, "ok is false");
  console.log();

  // --- Test 4: watch() detects human navigation ---
  console.log("Test 4: watch() - detects human navigation");
  await session.page.goto("https://example.com", { waitUntil: "domcontentloaded" });

  // Human will navigate after 500ms
  setTimeout(() => {
    humanPage.goto("https://news.ycombinator.com").catch(() => {});
  }, 500);

  const r4 = await session.watch({ timeout: 5000 });
  assert(r4.interrupted === true, "detected navigation");
  assert(r4.reason === "navigation", `reason: ${r4.reason}`);
  assert(r4.currentUrl?.includes("news.ycombinator.com") === true, `navigated to HN`);
  console.log();

  // --- Test 5: watch() times out when no human action ---
  console.log("Test 5: watch() - timeout with no action");
  const start = Date.now();
  const r5 = await session.watch({ timeout: 1000 });
  const elapsed = Date.now() - start;
  assert(r5.interrupted === false, "not interrupted");
  assert(elapsed >= 900 && elapsed < 2000, `timed out in ${elapsed}ms`);
  console.log();

  // --- Test 6: watch() with urlPattern filter ---
  console.log("Test 6: watch() - urlPattern filter");
  await session.page.goto("https://example.com", { waitUntil: "domcontentloaded" });

  // Navigate to a non-matching URL first, then a matching one
  setTimeout(() => {
    humanPage.goto("https://httpbin.org/html").catch(() => {});
  }, 300);
  setTimeout(() => {
    humanPage.goto("https://news.ycombinator.com").catch(() => {});
  }, 800);

  const r6 = await session.watch({
    timeout: 5000,
    urlPattern: /news\.ycombinator/,
  });
  assert(r6.interrupted === true, "detected matching navigation");
  assert(r6.currentUrl?.includes("news.ycombinator") === true, "matched pattern");
  console.log();

  // --- Summary ---
  console.log("===================");
  console.log(`Results: ${passed} passed, ${failed} failed`);
  console.log("===================");

  await humanBrowser.close();
  await session.disconnect();
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error("Fatal:", err.message);
  process.exit(1);
});
