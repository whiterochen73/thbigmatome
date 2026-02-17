import { defineConfig, devices } from '@playwright/test';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: 'list',
  use: {
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',
    headless: true,
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
  // webServer設定: テスト実行時にサーバーを自動起動
  // BEとFEの両方を起動する
  webServer: [
    {
      command: `bash -lc "cd ${path.resolve(__dirname, '../thbigmatome')} && bundle exec rails s -p 3000 -b 127.0.0.1 -e test"`,
      url: 'http://127.0.0.1:3000/api/v1/teams',
      reuseExistingServer: true,
      timeout: 90000,
    },
    {
      command: 'npm run dev',
      url: 'http://localhost:5173',
      reuseExistingServer: true,
      timeout: 30000,
    },
  ],
});
