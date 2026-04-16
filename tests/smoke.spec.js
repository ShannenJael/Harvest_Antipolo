const { test, expect } = require("@playwright/test");

test("homepage loads with key navigation", async ({ page }) => {
  await page.goto("/");

  await expect(page).toHaveTitle(/Harvest Baptist Church Antipolo/);
  await expect(
    page.getByRole("heading", { level: 1, name: "Harvest Baptist Church Antipolo" })
  ).toBeVisible();
  await expect(page.getByRole("link", { name: "Plan Your Visit" }).first()).toHaveAttribute(
    "href",
    /pages\/visit\.html/
  );
});

test("visit page shows service times and directions", async ({ page }) => {
  await page.goto("/pages/visit.html");

  await expect(page).toHaveTitle(/Plan Your Visit/);
  await expect(page.getByRole("heading", { level: 1, name: "Plan Your Visit" })).toBeVisible();
  await expect(page.getByRole("heading", { level: 2, name: "Service Times" })).toBeVisible();
  await expect(page.locator(".service-list .service-name", { hasText: "Sunday Worship Service" })).toBeVisible();
  await expect(
    page.locator(".visit-location .directions-info").getByText("Block 50 Lot 9, Phase 3-A", { exact: false })
  ).toBeVisible();
});
