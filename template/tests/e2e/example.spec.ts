import { test, expect } from "@playwright/test";

test.describe("Example Page", () => {
  test("should load the home page", async ({ page }) => {
    await page.goto("/");

    // Authenticated — should not redirect to login
    await expect(page).not.toHaveURL(/\/login/);

    // ADAPT: check for content specific to your app
    await expect(page.locator("body")).toBeVisible();
  });

  test("should display user-specific content", async ({ page }) => {
    await page.goto("/");

    // ADAPT: check for authenticated user content
    // await expect(page.locator("text=E2E Test User")).toBeVisible();
  });
});
