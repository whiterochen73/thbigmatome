import { test, expect } from '@playwright/test'
import { TEST_TEAM_NAME, TEST_USER } from './env'

const INVALID_USER = {
  name: 'invalid_user',
  password: 'wrongpassword',
}

test.describe('認証', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login')
  })

  test('ログイン正常系: 有効な認証情報でログインするとホーム（/）へ遷移する', async ({ page }) => {
    await page.locator('#loginName').fill(TEST_USER.name)
    await page.locator('#password').fill(TEST_USER.password)
    await page.locator('button[type="submit"]').click()

    // ログイン後の遷移先はホーム（/）。パスを完全一致で見る（/menu や /login のまま、でも通らないように）
    await expect(page).toHaveURL((url) => url.pathname === '/', { timeout: 10000 })
    // チーム 1 件のユーザーのホームはそのチームのシーズン画面。割り当てたチーム名が見出しに出る
    await expect(page.locator('.v-app-bar')).toContainText(TEST_TEAM_NAME, { timeout: 10000 })
    await expect(page.locator('#loginName')).toHaveCount(0)
  })

  test('ログインエラー系: 無効な認証情報でエラーメッセージが表示され、ログイン画面に留まる', async ({
    page,
  }) => {
    await page.locator('#loginName').fill(INVALID_USER.name)
    await page.locator('#password').fill(INVALID_USER.password)
    await page.locator('button[type="submit"]').click()

    const errorMessage = page.locator('.error-message')
    await expect(errorMessage).toBeVisible({ timeout: 5000 })
    await expect(errorMessage).toContainText('ログインIDまたはパスワードが間違っています')
    await expect(page).toHaveURL(/\/login/)
  })

  test('未ログインで保護された画面を開くと、ログイン画面へ飛び、ログイン後に元の画面へ戻る', async ({
    page,
  }) => {
    await page.goto('/teams')
    await expect(page).toHaveURL(
      (url) => url.pathname === '/login' && url.searchParams.get('redirect') === '/teams',
    )

    await page.locator('#loginName').fill(TEST_USER.name)
    await page.locator('#password').fill(TEST_USER.password)
    await page.locator('button[type="submit"]').click()

    await expect(page).toHaveURL((url) => url.pathname === '/teams', { timeout: 10000 })
  })
})
