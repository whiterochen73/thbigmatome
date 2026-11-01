import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { tableCell } from '../tableCells'

// Test Basis: thbig-dugout-ui-unification-design.md §2.5（1 行 = 名前＋要点 2 つ＋操作メニュー）/ §2.8（表は縦積み）/ §4.2 段 4
describe('tableCell（縦積み行の列の役割）', () => {
  it('役割ごとに ui-cell と ui-cell--<役割> の class を返す', () => {
    expect(tableCell.lead.class).toBe('ui-cell ui-cell--lead')
    expect(tableCell.title.class).toBe('ui-cell ui-cell--title')
    expect(tableCell.sub1.class).toBe('ui-cell ui-cell--sub1')
    expect(tableCell.sub2.class).toBe('ui-cell ui-cell--sub2')
    expect(tableCell.note.class).toBe('ui-cell ui-cell--note')
    expect(tableCell.act.class).toBe('ui-cell ui-cell--act')
  })

  it('labeled は見出しを値の前に出す印（ui-cell--labeled）を足す', () => {
    expect(tableCell.sub1Labeled.class).toBe('ui-cell ui-cell--sub1 ui-cell--labeled')
    expect(tableCell.sub2Labeled.class).toBe('ui-cell ui-cell--sub2 ui-cell--labeled')
    expect(tableCell.noteLabeled.class).toBe('ui-cell ui-cell--note ui-cell--labeled')
    expect(tableCell.note2.class).toBe('ui-cell ui-cell--note2')
    expect(tableCell.note2Labeled.class).toBe('ui-cell ui-cell--note2 ui-cell--labeled')
  })
})

describe('PageLayout の縦積み行の CSS', () => {
  const source = readFileSync(
    resolve(process.cwd(), 'src/components/shared/PageLayout.vue'),
    'utf8',
  )
  const css = source.match(/<style scoped>([\s\S]*)<\/style>/)![1]!

  it('縦積みの行（tr--mobile）は grid。名前は上、要点 2 つは下、操作は右端、左に番号', () => {
    expect(css).toMatch(/tr\.v-data-table__tr--mobile\)\s*\{\s*display:\s*grid/)
    expect(css).toMatch(/'lead title title act'/)
    expect(css).toMatch(/'lead sub1 sub2 act'/)
    expect(css).toMatch(/'lead note note act'/)
  })

  it('class の無い列は出さず、ui-cell の列だけ出す。見出し（td-title）は labeled の列だけ出す', () => {
    expect(css).toMatch(/> td\)\s*\{\s*display:\s*none/)
    expect(css).toMatch(/td\.ui-cell\)\s*\{\s*display:\s*block/)
    expect(css).toMatch(/\.ui-cell \.v-data-table__td-title\)\s*\{\s*display:\s*none/)
    expect(css).toMatch(/ui-cell--labeled \.v-data-table__td-title\)\s*\{\s*display:\s*block/)
  })

  it('名前（title）は太字', () => {
    expect(css).toMatch(/\.ui-cell--title\)\s*\{[^}]*font-weight:\s*700/)
  })

  it('操作が 3 つ以上の行: アイコン群（row-actions--full）は 600px 未満で隠し、操作メニュー（row-menu）は 600px 以上で隠す', () => {
    expect(css).toMatch(
      /@media \(max-width: 599\.98px\)\s*\{\s*\.page-layout :deep\(\.row-actions--full\)\s*\{\s*display:\s*none/,
    )
    const menu = readFileSync(resolve(process.cwd(), 'src/components/shared/RowMenu.vue'), 'utf8')
    expect(menu).toMatch(/@media \(min-width: 600px\)\s*\{\s*\.row-menu\s*\{\s*display:\s*none/)
  })

  it('縦積みの行のホバーは行全体に 1 枚（セルごとに地を付けない）。行の地（bg-state-done など）を消さない', () => {
    expect(css).toMatch(/> td\)\s*\{[^}]*background:\s*transparent !important/)
    expect(css).toMatch(/> td::after\)\s*\{\s*content:\s*none !important/)
    expect(css).toMatch(
      /tr\.v-data-table__tr--mobile:hover::before\)\s*\{[^}]*position:\s*absolute;\s*inset:\s*0/,
    )
  })

  it('長い説明（text-truncate）は PC 用の最大幅を外し、セルの幅（100%）で省略する。外すだけだと nowrap のまま横にはみ出す', () => {
    expect(css).toMatch(
      /\.ui-cell \.text-truncate\)\s*\{\s*display:\s*block;\s*max-width:\s*100% !important/,
    )
  })

  // PC（600px 以上）の表は変えない。役割 class の装飾（太字・13px・padding・説明の最大幅）はスマホの縦積みの行（tr--mobile）の中だけに効かせる（subtask_1791u の blocker）
  it('名前・要点・補足・操作・説明（text-truncate）の装飾の規則は、全て tr.v-data-table__tr--mobile の中に限る', () => {
    const rules = [...css.matchAll(/([^{}]+)\{([^{}]*)\}/g)].map((m) => ({
      selector: m[1]!.trim(),
      body: m[2]!,
    }))
    const scoped = rules.filter(({ selector }) =>
      /ui-cell--(title|sub1|sub2|note2?|act)\b|\.text-truncate/.test(selector),
    )
    expect(scoped.length).toBeGreaterThanOrEqual(7)
    for (const { selector } of scoped) {
      expect(selector, selector).toContain('tr.v-data-table__tr--mobile')
    }
  })
})
