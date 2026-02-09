/**
 * Playwright Authentication Setup
 *
 * Seeds a test user and creates a valid JWT session for authenticated E2E tests.
 * Runs before other tests via the "setup" project in playwright.config.ts.
 *
 * ADAPT FOR YOUR PROJECT:
 * 1. Update TEST_USER with your test user fields
 * 2. Update the db.insert() call to match your users table schema
 * 3. Update the JWT token payload to match your session shape
 * 4. Update cookie name if your NextAuth config differs
 */
import { test as setup } from "@playwright/test";
import { encode } from "next-auth/jwt";
// ADAPT: import your db client and users table
// import { db, users } from "@your-package/db";

// Test user constants — adapt fields to your schema
const TEST_USER = {
  id: "e2e-test-user",
  email: "e2e-test@company.com",
  name: "E2E Test User",
};

// Storage state file path (must match playwright.config.ts)
const AUTH_FILE = "playwright/.auth/user.json";

setup("authenticate", async ({ page }) => {
  const authSecret = process.env.AUTH_SECRET;

  if (!authSecret) {
    throw new Error("AUTH_SECRET environment variable is required for E2E tests");
  }

  // ADAPT: Uncomment and modify for your database
  // if (!db) {
  //   throw new Error("DATABASE_URL environment variable is required for E2E tests");
  // }

  // 1. Seed test user in database
  // ADAPT: Replace with your users table insert/upsert
  // await db
  //   .insert(users)
  //   .values({
  //     id: TEST_USER.id,
  //     email: TEST_USER.email,
  //     name: TEST_USER.name,
  //   })
  //   .onConflictDoUpdate({
  //     target: users.id,
  //     set: {
  //       email: TEST_USER.email,
  //       name: TEST_USER.name,
  //       updatedAt: new Date(),
  //     },
  //   });

  console.log(`[auth.setup] Seeded test user: ${TEST_USER.email}`);

  // 2. Create a valid JWT session token
  const now = Math.floor(Date.now() / 1000);
  const expiresAt = now + 24 * 60 * 60; // 24 hours

  const token = await encode({
    token: {
      id: TEST_USER.id,
      email: TEST_USER.email,
      name: TEST_USER.name,
      sub: TEST_USER.id,
      iat: now,
      exp: expiresAt,
    },
    secret: authSecret,
    // ADAPT: NextAuth v5 uses "authjs.session-token" by default
    // Older versions may use "next-auth.session-token"
    salt: "authjs.session-token",
  });

  console.log(`[auth.setup] Created JWT session token`);

  // 3. Store session cookie in Playwright storageState
  await page.context().addCookies([
    {
      name: "authjs.session-token", // ADAPT: match your cookie name
      value: token,
      domain: "localhost",
      path: "/",
      httpOnly: true,
      secure: false, // false for localhost
      sameSite: "Lax",
    },
  ]);

  // 4. Save the storage state to file for reuse by other tests
  await page.context().storageState({ path: AUTH_FILE });

  console.log(`[auth.setup] Saved storageState to ${AUTH_FILE}`);
});
