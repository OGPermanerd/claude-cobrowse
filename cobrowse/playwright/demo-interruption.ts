#!/usr/bin/env npx tsx
/**
 * demo-interruption.ts - Demonstrates human interruption detection
 *
 * Covers three scenarios:
 *   1. Normal action that completes (no interruption)
 *   2. Slow page reading where human can navigate away (do + error catch)
 *   3. Explicit wait for human action (watch)
 *
 * Usage: npx tsx demo-interruption.ts
 */

import { CobrowseSession } from "./cobrowse.js";

async function main() {
  console.log("Connecting to Chrome via CDP...");
  const session = await CobrowseSession.connect();
  console.log(`Connected. Current page: ${session.url()}\n`);

  // --- Demo 1: page.goto + read (our own navigation, should not false-positive) ---
  console.log("=== Demo 1: Navigate + read title (should succeed) ===");
  const r1 = await session.do(async (page) => {
    await page.goto("https://news.ycombinator.com", {
      waitUntil: "domcontentloaded",
    });
    return page.title();
  });
  console.log("Result:", JSON.stringify(r1, null, 2));
  console.log();

  // --- Demo 2: Slow operation (try navigating in noVNC during this!) ---
  console.log("=== Demo 2: Slowly reading 30 links... ===");
  console.log(">>> Navigate away in noVNC to trigger interruption! <<<\n");

  const r2 = await session.do(async (page) => {
    const links: string[] = [];
    const items = page.locator(".titleline > a");
    const count = await items.count();

    for (let i = 0; i < Math.min(count, 30); i++) {
      const text = await items.nth(i).textContent();
      links.push(text || "(empty)");
      console.log(`  [${i + 1}] ${text}`);
      // Deliberate 500ms delay per item - gives human time to intervene
      await page.waitForTimeout(500);
    }

    return links;
  });

  if (r2.interrupted) {
    console.log(`\nInterrupted while reading!`);
    console.log(`  Reason: ${r2.reason}`);
    console.log(`  Was at: ${r2.previousUrl}`);
    console.log(`  Now at: ${r2.currentUrl}`);
    if (r2.error) console.log(`  Error:  ${r2.error}`);
  } else {
    console.log(`\nRead ${r2.value?.length} links without interruption.`);
  }
  console.log();

  // --- Demo 3: watch() - explicitly wait for human to navigate ---
  console.log("=== Demo 3: Waiting for you to navigate (15s timeout) ===");
  console.log(">>> Click any link in the browser via noVNC <<<\n");

  const r3 = await session.watch({ timeout: 15_000 });

  if (r3.interrupted) {
    console.log(`Detected your action!`);
    console.log(`  From: ${r3.previousUrl}`);
    console.log(`  To:   ${r3.currentUrl}`);
    console.log(`  -> Claude would now adapt to the new page.`);
  } else {
    console.log("Timeout - no navigation detected.");
  }
  console.log();

  // --- Summary ---
  console.log("=== Done ===");
  console.log(`Final page: ${session.url()}`);

  await session.disconnect();
}

main().catch((err) => {
  console.error("Fatal:", err.message);
  process.exit(1);
});
