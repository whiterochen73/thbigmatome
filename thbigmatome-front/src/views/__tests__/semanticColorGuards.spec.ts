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

function coloredTags() {
  return vueFiles(srcDir).flatMap((file) => {
    const source = readFileSync(file, 'utf8')
    const path = relative(srcDir, file).split(sep).join('/')
    return [...source.matchAll(/<v-(?:btn|chip)\b(?:"[^"]*"|'[^']*'|[^>"'])*>/g)].map((match) => ({
      tag: match[0],
      location: `${path}:${source.slice(0, match.index).split('\n').length}`,
    }))
  })
}

// Test Basis: thbig-dugout-visual-stage5-mapping.md §2 R4 / subtask_1787u 申し送り4
it('v-btn と v-chip は error の塗りを使わない', () => {
  const violations = coloredTags()
    .filter(({ tag }) =>
      /(?:^|\s)color\s*=\s*["']error["']|\s:color\s*=\s*"[^"]*'error'[^"]*"|\s:color\s*=\s*'[^']*"error"[^']*'/.test(
        tag,
      ),
    )
    .map(({ location }) => `${location} color=error`)
  expect(violations).toEqual([])
})

// Test Basis: subtask_1790a §1 / thbig-dugout-visual-stage5-mapping.md §2 R1, §4
it('v-chip の color にテーマの状態色リテラルを渡さない', () => {
  const legacy =
    /^(?:success|warning|secondary|info|error)$|['"](?:success|warning|secondary|info|error)['"]/
  const violations = coloredTags()
    .filter(({ tag }) => tag.startsWith('<v-chip'))
    .filter(({ tag }) => {
      const color = tag.match(/(?:^|\s):?color\s*=\s*(["'])(.*?)\1/)
      return color && legacy.test(color[2])
    })
    .map(({ location }) => `${location} v-chip color uses a theme status literal`)
  expect(violations).toEqual([])
})

// Test Basis: thbig-dugout-visual-stage5-mapping.md §2 R1 / subtask_1787u 申し送り4
it('役割色を使う v-btn と v-chip は flat または明示した分岐を持つ', () => {
  const token =
    /['"](?:state-[\w-]+|absence-[\w-]+|zone-[\w-]+|date-[\w-]+|result-[\w-]+|tag-[\w-]+|action)['"]/
  const allowedElevated = [
    {
      path: 'components/AtBatCard.vue',
      marker: 'saveEdit',
      reason: '編集フォームの保存は既存の elevated 塗り',
    },
    {
      path: 'components/pitcher/PitcherAppearanceTab.vue',
      marker: 'saveAll',
      reason: '登板記録の保存は既存の elevated 塗り',
    },
    {
      path: 'components/squad/SquadTextGenerator.vue',
      marker: 'copyAndSave',
      reason: '生成結果の保存は既存の elevated 塗り',
    },
  ]
  const seen = new Map<string, number>()
  const violations = coloredTags()
    .filter(({ tag }) => /(?:^|\s):?color\s*=/.test(tag) && token.test(tag))
    .filter(({ tag }) => !/\bvariant\s*=\s*["']flat["']|\s:variant\s*=/.test(tag))
    .filter(({ tag, location }) => {
      const path = location.replace(/:\d+$/, '')
      const allowed = allowedElevated.find(
        (item) => item.path === path && tag.includes(item.marker),
      )
      if (allowed && /\bcolor="action"/.test(tag) && /\bvariant="elevated"/.test(tag)) {
        seen.set(path, (seen.get(path) ?? 0) + 1)
        return false
      }
      return true
    })
    .map(({ location }) => `${location} semantic color requires variant="flat" or :variant`)
  allowedElevated.forEach(({ path, reason }) => {
    if (seen.get(path) !== 1)
      violations.push(`${path} expected one filled elevated action button (${reason})`)
  })
  expect(violations).toEqual([])
})

// Test Basis: subtask_1787u 申し送り3 / thbig-dugout-visual-stage5-mapping.md §2 R5
it('四つのトグル群は border-strong の枠を持つ', () => {
  for (const [path, count] of [
    ['views/PlayerCardsView.vue', 2],
    ['components/squad/SquadTextGenerator.vue', 2],
  ] as const) {
    const source = readFileSync(resolve(srcDir, path), 'utf8')
    const toggles = [...source.matchAll(/<v-btn-toggle\b(?:"[^"]*"|'[^']*'|[^>"'])*>/g)].map(
      (match) => match[0],
    )
    expect(toggles, path).toHaveLength(count)
    toggles.forEach((tag) =>
      expect(tag, path).toContain("borderColor: 'rgb(var(--v-theme-border-strong))'"),
    )
  }
})

// Test Basis: subtask_1790a §2 / thbig-dugout-local-test-recipe.md v-btn-toggle の枠
it('八つのトグル群は outlined の border-strong 枠を持つ', () => {
  const toggles = vueFiles(srcDir).flatMap((file) => {
    const source = readFileSync(file, 'utf8')
    const path = relative(srcDir, file).split(sep).join('/')
    return [...source.matchAll(/<v-btn-toggle\b(?:"[^"]*"|'[^']*'|[^>"'])*>/g)].map((match) => ({
      tag: match[0],
      location: `${path}:${source.slice(0, match.index).split('\n').length}`,
    }))
  })
  // 7 → 8: cmd_1784 段2b の AsOfDateBar（過去分の修正の試合前／試合後の切り替え）
  expect(toggles).toHaveLength(8)
  const violations = toggles
    .filter(
      ({ tag }) =>
        !/\bvariant="outlined"/.test(tag) ||
        !tag.includes("borderColor: 'rgb(var(--v-theme-border-strong))'"),
    )
    .map(({ location }) => `${location} v-btn-toggle requires outlined border-strong`)
  expect(violations).toEqual([])
})

// Test Basis: subtask_1790c §1, §4 / thbig-dugout-visual-refresh-design.md §6.2
it('対象の scoped CSS に固定の明るい背景を残さない', () => {
  const violations = [
    'components/AtBatCard.vue',
    'components/PlayerCardItem.vue',
    'views/PlayerDetailView.vue',
    'views/PlayerCardDetailView.vue',
    'views/GameRecordDetailView.vue',
    'views/LoginForm.vue',
  ].flatMap((path) => {
    const source = readFileSync(resolve(srcDir, path), 'utf8')
    const css = source.match(/<style scoped>([\s\S]*?)<\/style>/)?.[1] ?? ''
    return [
      ...css.matchAll(
        /^\s*(?:background(?:-color)?|--[\w-]+-bg)\s*:\s*[^;]*(?:#[\da-f]{3,8}\b|rgba?\(\s*\d|hsla?\(\s*\d|\b(?:white|ghostwhite|whitesmoke|snow)\b)[^;]*;/gim,
      ),
    ].map((match) => `${path} scoped CSS fixed light background: ${match[0].trim()}`)
  })
  expect(violations).toEqual([])
})

// Test Basis: subtask_1790c §3, §4 / thbig-dugout-visual-stage5-mapping.md §2 R3
it('outlined の表示・絞り込みトグルは選択中の primary 塗りを持つ', () => {
  const paths = [
    'views/PlayerCardsView.vue',
    'views/GameRecordListView.vue',
    'views/SeasonPortal.vue',
  ]
  const violations = paths.flatMap((path) => {
    const source = readFileSync(resolve(srcDir, path), 'utf8')
    return [...source.matchAll(/<v-btn-toggle\b(?:"[^"]*"|'[^']*'|[^>"'])*>/g)]
      .filter((match) => /\bvariant="outlined"/.test(match[0]))
      .filter((match) => !/\bselected-class="bg-primary"/.test(match[0]))
      .map(
        (match) =>
          `${path}:${source.slice(0, match.index).split('\n').length} outlined toggle requires selected-class="bg-primary"`,
      )
  })
  expect(violations).toEqual([])
})

// Test Basis: thbig-dugout-ui-unification-design.md §2.1（画面独自の帯をやめ、タイトルと戻り先はヘッダーバーへ。subtask_1790c の「帯は on-primary を透過させない」は帯ごと無くなった）
it('選手詳細・選手カード詳細は画面独自の見出し帯・戻るボタンを持たない（on-primary の帯はバーだけ）', () => {
  for (const path of ['views/PlayerDetailView.vue', 'views/PlayerCardDetailView.vue']) {
    const source = readFileSync(resolve(srcDir, path), 'utf8')
    expect(source, path).not.toContain('detail-card-header')
    expect(source, path).not.toContain('detail-back-btn')
    expect(source, path).not.toContain('--v-theme-on-primary')
    expect(source, path).toContain('useAppBarTitle')
  }
})

// Test Basis: thbig-dugout-visual-stage5-mapping.md §6, §7 b9-1〜b9-7
it('ブランド色の旧変数を残さず見出しはテーマ色を使う', () => {
  const base = readFileSync(resolve(srcDir, 'assets/base.css'), 'utf8')
  const app = readFileSync(resolve(srcDir, 'App.vue'), 'utf8')
  const pageHeader = readFileSync(resolve(srcDir, 'components/shared/PageHeader.vue'), 'utf8')
  expect(base).not.toMatch(/--color-(?:home|visitor)/)
  expect(app).not.toContain('--ai: var(--color-visitor)')
  expect(pageHeader).toContain('color: rgb(var(--v-theme-link));')
  expect(pageHeader).toContain('border-left: 3px solid rgb(var(--v-theme-link));')
})
