import { test, expect, type Page } from '@playwright/test'
import { API_URL, TEST_TEAM_NAME, TEST_USER } from './env'

/**
 * ログインヘルパー: ログインフォームを使って認証し、ホーム（/）に着くまで待つ
 */
async function login(page: Page) {
  await page.goto('/login')
  await page.locator('#loginName').fill(TEST_USER.name)
  await page.locator('#password').fill(TEST_USER.password)
  await page.locator('button[type="submit"]').click()
  await expect(page).toHaveURL((url) => url.pathname === '/', { timeout: 10000 })
  await expect(page.locator('.v-app-bar')).toContainText(TEST_TEAM_NAME, { timeout: 10000 })
}

/** ログイン済みの page から、テストユーザーに割り当たったチームの id を引く */
async function myTeamId(page: Page): Promise<number> {
  const response = await page.request.get(`${API_URL}/users/me/teams`)
  expect(response.status()).toBe(200)
  const teams: Array<{ id: number; name: string }> = await response.json()
  const team = teams.find((t) => t.name === TEST_TEAM_NAME)
  expect(team, `${TEST_TEAM_NAME} が users/me/teams に無い（e2e:seed を流す）`).toBeTruthy()
  return team!.id
}

test.describe('ロスター', () => {
  test.beforeEach(async ({ page }) => {
    await login(page)
  })

  test('ホーム: 自分のチームのシーズン画面が開き、タブが並ぶ', async ({ page }) => {
    for (const label of ['カレンダー', 'チーム編成', 'ロスター', '昇降格履歴', '離脱者']) {
      await expect(page.locator('.v-tab', { hasText: label })).toBeVisible()
    }
    // 開いた直後の既定はカレンダー
    await expect(page.locator('.v-tab--selected')).toContainText('カレンダー')
  })

  test('左メニューは既定で閉じていて、ハンバーガーで開く', async ({ page }) => {
    const drawer = page.locator('.v-navigation-drawer')
    await expect(drawer).not.toHaveClass(/v-navigation-drawer--active/)

    await page.locator('.v-app-bar-nav-icon').click()
    await expect(drawer).toHaveClass(/v-navigation-drawer--active/)
    await expect(drawer.locator('.v-list-item', { hasText: 'ホーム' })).toBeVisible()
    await expect(drawer.locator('.v-list-item', { hasText: '選手カード' })).toBeVisible()
  })

  test('ホームの「ロスター」タブで、ロスターが同じ画面内に開く', async ({ page }) => {
    await page.locator('.v-tab', { hasText: 'ロスター' }).click()

    // ホームはチーム 1 件なら SeasonPortal をそのまま描くので、URL は / のまま tab だけが付く
    await expect(page).toHaveURL(
      (url) => url.pathname === '/' && url.searchParams.get('tab') === 'roster',
    )
    await expect(page.getByTestId('count-status')).toContainText('0/29人', { timeout: 10000 })
  })

  test('チーム一覧: 表が出て、割り当てたチームが載る', async ({ page }) => {
    await page.goto('/teams')
    await expect(page.locator('.v-data-table')).toBeVisible({ timeout: 10000 })
    await expect(page.locator('.v-data-table')).toContainText(TEST_TEAM_NAME)
  })

  test('旧 URL /teams/:id/roster は season?tab=roster へ転送され、1軍 0 人・2軍に選手 2 人が出る', async ({
    page,
  }) => {
    const teamId = await myTeamId(page)
    await page.goto(`/teams/${teamId}/roster`)

    await expect(page).toHaveURL(
      (url) =>
        url.pathname === `/teams/${teamId}/season` && url.searchParams.get('tab') === 'roster',
    )
    // 1軍 0/29 人（登録前）
    await expect(page.getByTestId('count-status')).toContainText('0/29人', { timeout: 10000 })
    // 2軍に seed の 2 人（短縮名で表示される）
    await expect(page.locator('tr', { hasText: '投1' })).toBeVisible()
    await expect(page.locator('tr', { hasText: '野2' })).toBeVisible()
    await expect(page.locator('.promote-btn')).toHaveCount(2)
  })

  test('昇格操作: 昇格ボタンで 2軍の選手が 1軍へ移る（保存はしない）', async ({ page }) => {
    const teamId = await myTeamId(page)
    await page.goto(`/teams/${teamId}/season?tab=roster`)
    await expect(page.getByTestId('count-status')).toContainText('0/29人', { timeout: 10000 })

    await page.locator('tr', { hasText: '投1' }).locator('.promote-btn').click()

    await expect(page.getByTestId('count-status')).toContainText('1/29人')
    // 2軍に残るのは野手 1 人。昇格ボタンは 1 つに減る
    await expect(page.locator('.promote-btn')).toHaveCount(1)
    await expect(page.getByTestId('save-roster')).toBeVisible()
  })
})
