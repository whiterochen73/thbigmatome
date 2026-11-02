import { flushPromises, type VueWrapper } from '@vue/test-utils'
import { VDataTable, VDataTableServer } from 'vuetify/components'

// 表のスマホ対応（段 4）の spec 用。縦積みにする表は mobile-breakpoint="sm" と ui-table--rows、列の cellProps の役割で、
// 横スクロールのまま残す表は mobile-breakpoint なし（縦積みにしない）・名前の列の fixed・列の minWidth で判定する。
type Header = { key?: string; cellProps?: { class?: string }; fixed?: boolean; minWidth?: number }

// サーバページングの表（VDataTableServer）も表として数える
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const dataTables = (wrapper: VueWrapper<any>) => [
  ...wrapper.findAllComponents(VDataTable),
  ...wrapper.findAllComponents(VDataTableServer),
]

// 表は何個目か（数）か、その表だけが持つ列の key（文字列）で指す。タブの中の表は key で指すほうが取り違えない
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function pickTable(wrapper: VueWrapper<any>, which: number | string) {
  const tables = dataTables(wrapper)
  const table =
    typeof which === 'number'
      ? tables[which]
      : tables.find((t) => (t.props('headers') as Header[]).some((h) => h.key === which))
  if (!table) throw new Error(`v-data-table が見つからない: ${which}`)
  return table
}

export const roleOf = (header: Header) => /ui-cell--(\w+)/.exec(header.cellProps?.class ?? '')?.[1]

// 縦積みの表: { 列の key: 役割 }（役割の無い列は出さない）と、表の props を返す
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function stackedLayout(wrapper: VueWrapper<any>, which: number | string = 0) {
  const table = pickTable(wrapper, which)
  const headers = table.props('headers') as Header[]
  const roles: Record<string, string> = {}
  for (const h of headers) {
    const role = roleOf(h)
    if (h.key && role) roles[h.key] = role
  }
  return {
    mobileBreakpoint: table.props('mobileBreakpoint'),
    rows: table.classes().includes('ui-table--rows'),
    roles,
  }
}

// 横スクロールの表: 縦積みにしない・固定の列・列の最小幅
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function scrollLayout(wrapper: VueWrapper<any>, which: number | string = 0) {
  const table = pickTable(wrapper, which)
  const headers = table.props('headers') as Header[]
  return {
    mobileBreakpoint: table.props('mobileBreakpoint'),
    rows: table.classes().includes('ui-table--rows'),
    fixedKeys: headers.filter((h) => h.fixed).map((h) => h.key),
    allHaveMinWidth: headers.every((h) => h.minWidth != null || h.key === 'data-table-expand'),
  }
}

// 操作メニュー（RowMenu）を開いて項目を押す。メニューは body へ teleport されるので document から探す
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function chooseRowMenuItem(wrapper: VueWrapper<any>, label: string) {
  await wrapper.find('[data-testid="row-menu"]').trigger('click')
  await flushPromises()
  const item = [...document.body.querySelectorAll('.v-list-item')].find(
    (i) => i.textContent?.trim() === label,
  ) as HTMLElement | undefined
  if (!item) throw new Error(`メニュー項目が無い: ${label}`)
  item.click()
  await flushPromises()
}
