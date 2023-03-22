import { firefox, Page } from 'playwright';
import path from 'path';
import * as fs from 'fs';

const authCacheFolder = 'auth_cache';
const resultFolder = 'results';
const screenshotsFolder = 'login_screenshots';

function maybeCreateScreenshotsFolder() {
  fs.mkdirSync(path.join(resultFolder, screenshotsFolder), { recursive: true });
}

function clearScreenshots() {
  fs.readdirSync(path.join(resultFolder, screenshotsFolder)).forEach(file => {
    fs.rmSync(path.join(resultFolder, screenshotsFolder, file));
  });
}

async function makeScreenshot(page: Page, slug: String) {
  const screenshot = await page.screenshot();
  fs.writeFileSync(path.join(resultFolder, screenshotsFolder, Date.now() + '_' + slug + '.png'), screenshot);
}

export async function loginAndSaveCookies(
  slug: string,
  url: string,
  destination_url_pattern: string,
  username_selector: string,
  password_selector: string,
  username: string,
  password: string): Promise<void> {

  maybeCreateScreenshotsFolder();
  clearScreenshots();
  const browser = await firefox.launch({ headless: true });
  const context = await browser.newContext()
  const page = await context.newPage()

  await page.goto(url);
  await page.fill(username_selector, username);
  await makeScreenshot(page, slug);

  // if password field is not visible, press actively enter so that it appears
  try {
    await page.waitForSelector(password_selector, { timeout: 2 });
  } catch (e) {
    await page.press(username_selector, 'Enter');
  }
  await makeScreenshot(page, slug);

  await page.fill(password_selector, password);
  await page.press(password_selector, 'Enter');
  await makeScreenshot(page, slug);

  await page.waitForURL(destination_url_pattern, { timeout: 10000 });
  await makeScreenshot(page, slug);

  const cookies = await context.cookies();
  const cookieJson = JSON.stringify(cookies);
  fs.writeFileSync(path.join(authCacheFolder, slug + '_cookies.json'), cookieJson);
  const sessionStorage = await page.evaluate(() => JSON.stringify(sessionStorage));
  fs.writeFileSync(path.join(authCacheFolder, slug + '_session_storage.json'), sessionStorage, 'utf-8');

  clearScreenshots();
  await browser.close();
}