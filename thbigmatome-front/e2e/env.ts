// e2e が使う接続先と前提データの名前。値は環境変数で差し替える（既定は docker compose の開発環境）
//
// E2E_BASE_URL … フロント（vite）の URL。playwright.config.ts の baseURL になる
// E2E_API_URL  … Rails API の URL（/api/v1 まで）。フロントの VITE_API_BASE_URL にも同じ値を渡す
export const BASE_URL = process.env.E2E_BASE_URL ?? 'http://localhost:5173'
export const API_URL = process.env.E2E_API_URL ?? 'http://localhost:3000/api/v1'

// `RAILS_ENV=test bin/rails e2e:seed`（thbigmatome/db/seeds/test.rb）が作るデータ
export const TEST_USER = {
  name: 'testuser',
  password: 'testpassword',
}
export const TEST_TEAM_NAME = 'テストチーム'
