import { test, expect } from '@playwright/test'

// TODO: テスト用ユーザー情報
// seeds.rb にユーザーデータなし、test/fixtures/ も未作成。
// 実際のテスト実行前に、Railsテスト環境DBに下記ユーザーを作成すること:
//   rails runner -e test "User.create!(name: 'testuser', display_name: 'テストユーザー', password: 'testpassword', role: :general)"
// または seeds_test.rb を作成して db:seed RAILS_ENV=test で投入すること。
const TEST_USER = {
  name: 'testuser',
  password: 'testpassword',
}
const INVALID_USER = {
  name: 'invalid_user',
  password: 'wrongpassword',
}

test.describe('認証', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login')
  })

  test('ログイン正常系: 有効な認証情報でログイン成功後メニューへ遷移', async ({ page }) => {
    await page.locator('#loginName').fill(TEST_USER.name)
    await page.locator('#password').fill(TEST_USER.password)
    await page.locator('button[type="submit"]').click()

    // ログイン成功後は /menu へリダイレクト
    await expect(page).toHaveURL(/\/menu/, { timeout: 10000 })
  })

  test('ログインエラー系: 無効な認証情報でエラーメッセージが表示される', async ({ page }) => {
    await page.locator('#loginName').fill(INVALID_USER.name)
    await page.locator('#password').fill(INVALID_USER.password)
    await page.locator('button[type="submit"]').click()

    // エラーメッセージが表示される
    const errorMessage = page.locator('.error-message')
    await expect(errorMessage).toBeVisible({ timeout: 5000 })
    await expect(errorMessage).toContainText('ログインIDまたはパスワードが間違っています')
  })
})
