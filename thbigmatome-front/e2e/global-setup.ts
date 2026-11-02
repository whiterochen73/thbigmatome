import { API_URL, BASE_URL, TEST_TEAM_NAME, TEST_USER } from './env'

// 前提（Rails と前提データ）が欠けた時に、各テストが 10 秒の待ちで落ちて原因が分からなくなるのを避ける。
// ここで落ちたら e2e/README.md の「前提」を見る
export default async function globalSetup() {
  const fail = (what: string, hint: string): never => {
    throw new Error(`e2e の前提が足りません: ${what}\n  → ${hint}`)
  }

  const front = await fetch(BASE_URL).catch(() => null)
  if (!front?.ok) {
    fail(
      `フロントに届きません（${BASE_URL}）`,
      'E2E_BASE_URL を確かめる。vite は playwright が自動で起こす設定',
    )
  }

  const login = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: TEST_USER.name, password: TEST_USER.password }),
  }).catch(() => null)
  if (!login) {
    fail(`API に届きません（${API_URL}）`, 'Rails を test 環境で起動し、E2E_API_URL を合わせる')
  } else if (!login.ok) {
    fail(
      `API は応答したが ${TEST_USER.name} でログインできません（HTTP ${login.status}）`,
      'RAILS_ENV=test bin/rails e2e:seed で前提データを入れる',
    )
  }

  const cookie = (login as Response).headers
    .getSetCookie()
    .map((c) => c.split(';')[0])
    .join('; ')
  const teams = (await (
    await fetch(`${API_URL}/users/me/teams`, { headers: { Cookie: cookie } })
  ).json()) as {
    name: string
  }[]
  if (!teams.some((t) => t.name === TEST_TEAM_NAME)) {
    fail(
      `${TEST_USER.name} に「${TEST_TEAM_NAME}」が割り当たっていません`,
      'RAILS_ENV=test bin/rails e2e:seed を流し直す（チームの user を結ぶ）',
    )
  }
}
