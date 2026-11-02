import { defineConfig, devices } from '@playwright/test'
import { API_URL, BASE_URL } from './e2e/env'

// e2e は「今の画面が、実 Rails（test 環境・前提データ入り）と繋がって動くか」を見る。
// Rails は起動しない（ホストに libvips も PostgreSQL も無いことが多い）。手順は e2e/README.md。
// フロントの vite だけここで起こす。既に BASE_URL で動いていればそれを使う（CI 以外）
const { port } = new URL(BASE_URL)

export default defineConfig({
  testDir: './e2e',
  globalSetup: './e2e/global-setup.ts',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: 'list',
  outputDir: 'test-results',
  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    headless: true,
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    // Yarn Berry。`yarn dev -- --port` だと `--` が vite に渡って効かないので付けない
    command: `yarn dev --host localhost --port ${port} --strictPort`,
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
    env: { VITE_API_BASE_URL: API_URL },
  },
})
