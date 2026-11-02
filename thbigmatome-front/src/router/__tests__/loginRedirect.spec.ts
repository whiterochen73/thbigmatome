import { describe, it, expect } from 'vitest'
import { sanitizeRedirect, loginLocation } from '../loginRedirect'

describe('sanitizeRedirect', () => {
  it.each([
    ['/teams', '/teams'],
    ['/teams/1/season?tab=roster', '/teams/1/season?tab=roster'],
    ['/teams/1/season/games/5#log', '/teams/1/season/games/5#log'],
  ])('サイト内のパス %s はそのまま返す', (input, expected) => {
    expect(sanitizeRedirect(input)).toBe(expected)
  })

  it.each([
    ['https://evil.example/', '外部 URL'],
    ['http://evil.example/', '外部 URL（http）'],
    ['//evil.example/', 'プロトコル相対 URL'],
    ['/\\evil.example/', 'バックスラッシュ（ブラウザが // と解釈する）'],
    ['\\\\evil.example/', '先頭がバックスラッシュ'],
    ['javascript:alert(1)', 'javascript スキーム'],
    ['teams', '先頭がスラッシュでない相対パス'],
    ['/\t/evil.example/', 'タブを挟んだ // の偽装'],
    ['/\n/evil.example/', '改行を挟んだ // の偽装'],
    ['/login', 'ログイン画面自身（ループ防止）'],
    ['/login?redirect=/teams', 'ログイン画面自身（クエリ付き）'],
    ['', '空文字'],
  ])('%s（%s）はホームに落とす', (input) => {
    expect(sanitizeRedirect(input)).toBe('/')
  })

  it('文字列でない値（undefined・null・数値・オブジェクト）はホームに落とす', () => {
    expect(sanitizeRedirect(undefined)).toBe('/')
    expect(sanitizeRedirect(null)).toBe('/')
    expect(sanitizeRedirect(1)).toBe('/')
    expect(sanitizeRedirect({ a: 1 })).toBe('/')
  })

  it('クエリが配列（?redirect=a&redirect=b）の時は先頭だけを見て、同じ検査を通す', () => {
    expect(sanitizeRedirect(['/teams', 'https://evil.example/'])).toBe('/teams')
    expect(sanitizeRedirect(['https://evil.example/', '/teams'])).toBe('/')
  })
})

describe('loginLocation', () => {
  it('元の画面を redirect に持たせる', () => {
    expect(loginLocation('/teams/1/season?tab=roster')).toEqual({
      path: '/login',
      query: { redirect: '/teams/1/season?tab=roster' },
    })
  })

  it('ホームは redirect を持たせない', () => {
    expect(loginLocation('/')).toEqual({ path: '/login' })
  })

  it('外部 URL は redirect に入れない', () => {
    expect(loginLocation('https://evil.example/')).toEqual({ path: '/login' })
  })
})
