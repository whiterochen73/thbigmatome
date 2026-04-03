import { test, expect, type Page } from '@playwright/test'

// TODO: テスト用ユーザー情報
// seeds.rb にユーザーデータなし。テスト実行前に下記コマンドで作成すること:
//   rails runner -e test "User.create!(name: 'testuser', display_name: 'テストユーザー', password: 'testpassword', role: :player)"
// また、チームデータ（roster確認用）も事前作成が必要:
//   rails runner -e test "Manager.create!(name: 'testmgr', display_name: 'テスト監督'); Team.create!(name: 'テストチーム', manager_id: Manager.first.id)"
const TEST_USER = {
  name: 'testuser',
  password: 'testpassword',
}

/**
 * ログインヘルパー: ログインフォームを使って認証する
 */
async function login(page: Page) {
  await page.goto('/login')
  await page.locator('#loginName').fill(TEST_USER.name)
  await page.locator('#password').fill(TEST_USER.password)
  await page.locator('button[type="submit"]').click()
  await expect(page).toHaveURL(/\/menu/, { timeout: 10000 })
}

test.describe('ロスター', () => {
  test.beforeEach(async ({ page }) => {
    await login(page)
  })

  test('ログイン後にメニュー画面が表示される', async ({ page }) => {
    // /menu にいることを確認
    await expect(page).toHaveURL(/\/menu/)
    // チーム選択セクションが存在する
    await expect(page.locator('.v-container')).toBeVisible()
  })

  test('チームリスト画面が表示される', async ({ page }) => {
    await page.goto('/teams')
    // v-data-table が存在する
    await expect(page.locator('.v-data-table')).toBeVisible({ timeout: 10000 })
  })

  test('ロスター画面表示: チームIDを取得してロスターページへ遷移', async ({ page }) => {
    // APIからチーム一覧を取得してteamIdを特定する
    const response = await page.request.get('http://localhost:3000/api/v1/teams')
    expect(response.status()).toBe(200)
    const teams: Array<{ id: number; name: string }> = await response.json()

    // チームデータが存在することを確認（シードデータ必須）
    expect(teams.length).toBeGreaterThan(0)

    const teamId = teams[0].id
    await page.goto(`/teams/${teamId}/roster`)

    // ロスター画面のタイトルバー (v-toolbar) が表示される
    await expect(page.locator('.v-toolbar').first()).toBeVisible({ timeout: 10000 })
  })

  test('昇格操作ボタンの存在確認', async ({ page }) => {
    // APIからチーム一覧を取得してteamIdを特定する
    const response = await page.request.get('http://localhost:3000/api/v1/teams')
    expect(response.status()).toBe(200)
    const teams: Array<{ id: number; name: string }> = await response.json()

    // チームデータが存在することを確認（シードデータ必須）
    expect(teams.length).toBeGreaterThan(0)

    const teamId = teams[0].id
    await page.goto(`/teams/${teamId}/roster`)

    // ロスター画面が読み込まれるまで待つ
    await expect(page.locator('.v-toolbar').first()).toBeVisible({ timeout: 10000 })

    // 昇格ボタン (1軍登録/降格ボタン) が表示されることを確認
    const promotionButtons = page.locator('button').filter({ hasText: /昇格|登録|1軍|降格/ })
    await expect(promotionButtons.first()).toBeVisible({ timeout: 5000 })
  })
})
