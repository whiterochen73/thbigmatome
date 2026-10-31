import { readdirSync, readFileSync } from 'node:fs'
import { relative, resolve, sep } from 'node:path'
import { expect, it } from 'vitest'

const viewsDir = resolve(process.cwd(), 'src/views')

function vueFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    if (entry.name === '__tests__') return []
    const path = resolve(dir, entry.name)
    if (entry.isDirectory()) return vueFiles(path)
    return entry.name.endsWith('.vue') ? [path] : []
  })
}

// Test Basis: thbig-dugout-visual-refresh-design.md §7 段4
it('does not use accent for filled view buttons except the navigation button', () => {
  // GamesView.vue:5 はログ取り込み画面への遷移ボタン。
  const allowedAccentButtons = new Set(['GamesView.vue:5'])
  const violations: string[] = []

  for (const file of vueFiles(viewsDir)) {
    const source = readFileSync(file, 'utf8')
    const path = relative(viewsDir, file).split(sep).join('/')
    for (const match of source.matchAll(/<v-btn\b[^>]*>/g)) {
      const tag = match[0]
      if (!/\bvariant\s*=\s*["'](?:flat|elevated)["']/.test(tag)) continue
      if (!/\bcolor\s*=\s*["']accent["']/.test(tag)) continue

      const line = source.slice(0, match.index).split('\n').length
      const location = `${path}:${line}`
      if (!allowedAccentButtons.has(location)) violations.push(location)
    }
  }

  expect(violations).toEqual([])
})
