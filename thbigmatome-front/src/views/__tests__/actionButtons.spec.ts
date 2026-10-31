import { readdirSync, readFileSync } from 'node:fs'
import { relative, resolve, sep } from 'node:path'
import { expect, it } from 'vitest'

const srcDir = resolve(process.cwd(), 'src')

function vueFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    if (entry.name === '__tests__') return []
    const path = resolve(dir, entry.name)
    if (entry.isDirectory()) return vueFiles(path)
    return entry.name.endsWith('.vue') ? [path] : []
  })
}

// Test Basis: thbig-dugout-visual-refresh-design.md §7 段4 / subtask_1787j
it('uses action for filled buttons while keeping identified navigation and row actions primary', () => {
  const allowedPrimaryButtons = [
    { path: 'views/GamesView.vue', marker: 'ログ取り込み', reason: '取り込み画面への遷移' },
    {
      path: 'views/SeasonPortal.vue',
      marker: 'seasonPortal.gameResultInput',
      reason: '試合結果入力画面への遷移',
    },
    {
      path: 'components/season/SeasonRosterTab.vue',
      marker: 'mdi-arrow-up',
      reason: '行ごとの昇格操作アイコン',
    },
    {
      path: 'components/squad/SquadTextGenerator.vue',
      marker: 'テンプレートから始める',
      reason: '並列の入口',
    },
  ]
  const seen = new Map<string, number>()
  const violations: string[] = []

  for (const file of [
    ...vueFiles(resolve(srcDir, 'views')),
    ...vueFiles(resolve(srcDir, 'components')),
  ]) {
    const source = readFileSync(file, 'utf8')
    const path = relative(srcDir, file).split(sep).join('/')
    for (const match of source.matchAll(/<v-btn\b(?:"[^"]*"|'[^']*'|[^>"'])*>/g)) {
      const tag = match[0]
      const line = source.slice(0, match.index).split('\n').length
      const location = `${path}:${line}`

      if (/:color\s*=\s*"[^"]*'accent'[^"]*"|:color\s*=\s*'[^']*"accent"[^']*'/.test(tag)) {
        violations.push(`${location} dynamic accent`)
      }

      if (!/\bvariant\s*=\s*["'](?:flat|elevated)["']/.test(tag)) continue
      const color = tag.match(/(?<!:)\bcolor\s*=\s*["'](accent|primary)["']/)?.[1]
      if (color === 'accent') {
        violations.push(`${location} accent`)
      } else if (color === 'primary') {
        const closingTag = source.indexOf('</v-btn', match.index + tag.length)
        const button = source.slice(
          match.index,
          closingTag < 0 ? match.index + tag.length : closingTag,
        )
        const allowed = allowedPrimaryButtons.filter(
          (item) => item.path === path && button.includes(item.marker),
        )
        if (allowed.length !== 1) {
          violations.push(`${location} primary`)
        } else {
          const key = `${path}:${allowed[0]!.marker}`
          seen.set(key, (seen.get(key) ?? 0) + 1)
        }
      }
    }
  }

  for (const item of allowedPrimaryButtons) {
    const key = `${item.path}:${item.marker}`
    if (seen.get(key) !== 1) violations.push(`${key} expected once (${item.reason})`)
  }
  expect(violations).toEqual([])
})
