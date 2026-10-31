import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import vuetify from '../vuetify'

// Test Basis: thbig-dugout-visual-refresh-design.md §6.1, §6.2, §6.4 (subtask_1787d)
const expected = {
  light: {
    background: '#F8F6F1',
    surface: '#FFFFFF',
    'on-surface': '#1A1A1A',
    'surface-variant': '#F1EEE6',
    'on-surface-variant': '#4A4A4A',
    'text-caption': '#666666',
    link: '#1B3A6B',
    'border-strong': '#857F70',
    'danger-ink': '#8a1420',
    'game-home': '#1B3A6B',
    'game-visitor': '#46565F',
    primary: '#1B3A6B',
    'state-done': '#ddefc9',
    'on-state-done': '#2f5a12',
    'state-todo': '#fbebc2',
    'on-state-todo': '#6d4a00',
    'state-edit': '#ffffff',
    'on-state-edit': '#1A1A1A',
    'state-warn': '#f7d9dc',
    'on-state-warn': '#8a1420',
    'state-info': '#d6e9f2',
    'on-state-info': '#12506b',
    'state-neutral': '#eeece7',
    'on-state-neutral': '#4a4a4a',
    'absence-out': '#f6dbe8',
    'on-absence-out': '#8a1c55',
    'absence-adjust': '#e3e7ea',
    'on-absence-adjust': '#3b4a54',
    'absence-cooldown': '#f9e0cf',
    'on-absence-cooldown': '#8a3f0c',
    'zone-roster': '#dcecef',
    'on-zone-roster': '#1f5a68',
    'zone-game': '#dfe4ee',
    'on-zone-game': '#1B3A6B',
    'date-game': '#dfe4ee',
    'on-date-game': '#1B3A6B',
    'date-interleague': '#d6e9f2',
    'on-date-interleague': '#12506b',
    'date-reserve': '#dcecef',
    'on-date-reserve': '#1f5a68',
    'date-travel': '#e3e7ea',
    'on-date-travel': '#3b4a54',
    'date-rain': '#e3e1db',
    'on-date-rain': '#4a4a4a',
    'result-win': '#ddefc9',
    'on-result-win': '#2f5a12',
    'result-loss': '#f7d9dc',
    'on-result-loss': '#8a1420',
    'result-draw': '#eeece7',
    'on-result-draw': '#4a4a4a',
    'result-nogame': '#e3e1db',
    'on-result-nogame': '#4a4a4a',
    action: '#2E7D32',
    'on-action': '#FFFFFF',
  },
  dark: {
    background: '#1A1A2E',
    surface: '#252545',
    'on-surface': '#E8E8F2',
    'surface-variant': '#2D2D50',
    'on-surface-variant': '#B8B8D0',
    'text-caption': '#A0A0B8',
    link: '#9DBBF2',
    'border-strong': '#7C7CB0',
    'danger-ink': '#ffb3b8',
    'game-home': '#9DBBF2',
    'game-visitor': '#B4C7D3',
    primary: '#4A72B8',
    'state-done': '#2c4a1c',
    'on-state-done': '#bfe59a',
    'state-todo': '#4d3a0c',
    'on-state-todo': '#ffd777',
    'state-edit': '#252545',
    'on-state-edit': '#E8E8F2',
    'state-warn': '#5a1a22',
    'on-state-warn': '#ffb3b8',
    'state-info': '#1f3f52',
    'on-state-info': '#a9dbf2',
    'state-neutral': '#33335a',
    'on-state-neutral': '#b8b8d0',
    'absence-out': '#5a1d3d',
    'on-absence-out': '#ffb8d8',
    'absence-adjust': '#2f3b44',
    'on-absence-adjust': '#c5d3dc',
    'absence-cooldown': '#5a2f10',
    'on-absence-cooldown': '#ffc7a0',
    'zone-roster': '#1d3b43',
    'on-zone-roster': '#a8d3dd',
    'zone-game': '#27345a',
    'on-zone-game': '#bcd0f5',
    'date-game': '#27345a',
    'on-date-game': '#bcd0f5',
    'date-interleague': '#1f3f52',
    'on-date-interleague': '#a9dbf2',
    'date-reserve': '#1d3b43',
    'on-date-reserve': '#a8d3dd',
    'date-travel': '#2f3b44',
    'on-date-travel': '#c5d3dc',
    'date-rain': '#33335a',
    'on-date-rain': '#b8b8d0',
    'result-win': '#2c4a1c',
    'on-result-win': '#bfe59a',
    'result-loss': '#5a1a22',
    'on-result-loss': '#ffb3b8',
    'result-draw': '#33335a',
    'on-result-draw': '#b8b8d0',
    'result-nogame': '#33335a',
    'on-result-nogame': '#b8b8d0',
    action: '#7CD08F',
    'on-action': '#082414',
  },
} as const

type ThemeName = keyof typeof expected
type Pair = readonly [string, string, number]
const textPair = (bg: string, fg: string): Pair => [bg, fg, 4.5]
const graphicPair = (bg: string, fg: string): Pair => [bg, fg, 3]
const pairs: Pair[] = [
  textPair('surface', 'on-surface'),
  textPair('background', 'on-surface'),
  textPair('surface', 'on-surface-variant'),
  textPair('background', 'on-surface-variant'),
  textPair('surface', 'text-caption'),
  textPair('background', 'text-caption'),
  textPair('surface-variant', 'text-caption'),
  textPair('surface-variant', 'on-surface'),
  textPair('surface-variant', 'on-surface-variant'),
  textPair('primary', '#FFFFFF'),
  textPair('surface', 'link'),
  graphicPair('surface', 'link'),
  graphicPair('surface', 'border-strong'),
  graphicPair('background', 'border-strong'),
  textPair('action', 'on-action'),
  graphicPair('background', 'action'),
  graphicPair('surface', 'action'),
  textPair('surface', 'danger-ink'),
  textPair('background', 'danger-ink'),
  textPair('surface', 'game-home'),
  textPair('surface', 'game-visitor'),
  textPair('surface', 'on-state-edit'),
  graphicPair('surface', 'on-state-edit'),
  graphicPair('surface', 'on-zone-roster'),
  textPair('zone-roster', 'on-surface'),
  graphicPair('surface', 'on-zone-game'),
  textPair('zone-game', 'on-surface'),
  ...[
    'state-done',
    'state-todo',
    'state-warn',
    'state-info',
    'state-neutral',
    'state-edit',
    'absence-out',
    'absence-adjust',
    'absence-cooldown',
    'zone-roster',
    'zone-game',
    'date-game',
    'date-interleague',
    'date-reserve',
    'date-travel',
    'date-rain',
    'result-win',
    'result-loss',
    'result-draw',
    'result-nogame',
  ].map((name): Pair => textPair(name, `on-${name}`)),
]

function rgb(hex: string): number[] {
  return [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16))
}
function luminance(hex: string): number {
  const linear = rgb(hex).map((v) => {
    const c = v / 255
    return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
  })
  return linear[0]! * 0.2126 + linear[1]! * 0.7152 + linear[2]! * 0.0722
}
function contrast(a: string, b: string): number {
  const values = [luminance(a), luminance(b)].sort((x, y) => y - x)
  return (values[0]! + 0.05) / (values[1]! + 0.05)
}

describe('subtask_1787d: §6.1, §6.2, §6.4 のテーマと全コントラスト組', () => {
  // Test Basis: cmd_1787 subtask_1787g dark ボタンの文字コントラスト
  it('light/dark の基本ボタン色は on-X を明示し、文字比 4.5 以上', () => {
    for (const name of ['light', 'dark'] as ThemeName[]) {
      const colors = vuetify.theme.themes.value[name]!.colors
      for (const key of ['primary', 'secondary', 'accent', 'success', 'warning', 'error', 'info']) {
        expect(colors[`on-${key}`], `${name}/on-${key}`).toMatch(/^#[0-9a-f]{6}$/i)
        expect(
          contrast(colors[key]!, colors[`on-${key}`]!),
          `${name}/${key}`,
        ).toBeGreaterThanOrEqual(4.5)
      }
    }
  })

  // Test Basis: cmd_1787 subtask_1787g Operator 決定 2026-10-31 ボタン最小文字サイズ
  it('x-small ボタンだけ 12px 以上、Vuetify の他のサイズ指定を保つ', () => {
    const css = readFileSync(resolve(process.cwd(), 'src/assets/button-size.css'), 'utf8')
    const plugin = readFileSync(resolve(process.cwd(), 'src/plugins/vuetify.ts'), 'utf8')
    expect(plugin).toContain("import '@/assets/button-size.css'")
    expect(css).toMatch(/\.v-btn--size-x-small\s*\{[^}]*--v-btn-size:\s*0\.75rem/s)
    expect(css).toMatch(/\.v-btn--size-x-small\s*\{[^}]*--v-btn-height:\s*24px/s)
    expect(css).toMatch(/\.v-btn--size-x-small\.v-btn--density-compact\s*\{[^}]*height:\s*20px/s)
    expect(css).not.toMatch(/\.v-btn--size-(?:small|default|large|x-large)|\.v-tab|expansion-panel/)
  })
  for (const name of ['light', 'dark'] as ThemeName[]) {
    it(`${name}: トークン値と全組の AA / 非文字 3:1`, () => {
      const colors = vuetify.theme.themes.value[name]!.colors
      for (const [key, value] of Object.entries(expected[name])) {
        expect(colors[key], `${name}/${key}`).toBe(value)
      }
      for (const [bg, fg, minimum] of pairs) {
        const background = colors[bg] ?? bg
        const foreground = colors[fg] ?? fg
        expect(contrast(background, foreground), `${name}: ${fg} on ${bg}`).toBeGreaterThanOrEqual(
          minimum,
        )
      }
    })

    // Test Basis: subtask_1787d 差し戻し修正（r2） 2(b)
    it(`${name}: 全テーマ色 X / on-X の文字比は 4.5 以上`, () => {
      const colors = vuetify.theme.themes.value[name]!.colors
      for (const [key, background] of Object.entries(colors)) {
        if (key.startsWith('on-')) continue
        const foreground = colors[`on-${key}`]
        if (!foreground) continue
        expect(
          contrast(background, foreground),
          `${name}: on-${key} on ${key}`,
        ).toBeGreaterThanOrEqual(4.5)
      }
    })
  }

  it('subtask_1787d 差し戻し修正（r2） 1, 2(a): HTML が Vuetify の layer 順を CSS より先に固定する', () => {
    const html = readFileSync(resolve(process.cwd(), 'index.html'), 'utf8')
    const order =
      '@layer vuetify-core, vuetify-components, vuetify-overrides, vuetify-utilities, vuetify-final;'
    expect(html).toContain(order)
    expect(html.indexOf(order)).toBeLessThan(html.indexOf('<link'))
    expect(html.indexOf(order)).toBeLessThan(html.indexOf('<script type="module"'))
  })
})
