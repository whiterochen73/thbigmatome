import { afterEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import MasterPanel from '../MasterPanel.vue'
import MasterAddButton from '../MasterAddButton.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'
import ja from '@/locales/ja.json'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({ legacy: false, locale: 'ja', messages: { ja } })
const wrappers: VueWrapper[] = []
const mountIt = (component: object, options: Record<string, unknown> = {}) => {
  const w = mount(component, { ...options, global: { plugins: [vuetify, i18n] } })
  wrappers.push(w as VueWrapper)
  return w
}
afterEach(() => wrappers.splice(0).forEach((w) => w.unmount()))
// v-show は style の display:none で隠す（detached の isVisible は当てにならない）
const hidden = (w: VueWrapper) =>
  (w.find('.master-panel__body').attributes('style') ?? '').includes('display: none')

// Test Basis: thbig-dugout-ui-unification-design.md §3 設定（マスタの行を「アイコン・名前・件数・追加（枠）・開閉」にそろえる）
describe('MasterPanel', () => {
  const panel = (props: Record<string, unknown> = {}, actions = false) =>
    mountIt(MasterPanel, {
      props: { title: '投手特徴', icon: 'mdi-tag-outline', count: 12, ...props },
      slots: {
        default: '<table id="body"><tr><td>行</td></tr></table>',
        ...(actions ? { actions: '<button id="act">追加</button>' } : {}),
      },
    })

  it('アイコン・名前・件数を 1 行に出し、既定では閉じている', () => {
    const w = panel()
    expect(w.find('.mdi-tag-outline').exists()).toBe(true)
    expect(w.find('h3 .master-panel__title').text()).toBe('投手特徴')
    expect(w.find('[data-testid="master-panel-count"]').text()).toBe('12件')
    expect(hidden(w)).toBe(true)
    expect(w.find('[data-testid="master-panel-toggle"]').attributes('aria-expanded')).toBe('false')
  })

  it('開閉ボタンで本文が出入りし、aria-expanded と aria-controls が本文に結びつく', async () => {
    const w = panel()
    const toggle = w.find('[data-testid="master-panel-toggle"]')
    await toggle.trigger('click')
    expect(hidden(w)).toBe(false)
    expect(toggle.attributes('aria-expanded')).toBe('true')
    expect(w.find('.mdi-chevron-up').exists()).toBe(true)
    const bodyId = toggle.attributes('aria-controls')!
    expect(w.find(`[id="${bodyId}"]`).exists()).toBe(true)
    await toggle.trigger('click')
    expect(hidden(w)).toBe(true)
    expect(w.find('.mdi-chevron-down').exists()).toBe(true)
  })

  it('defaultOpen なら最初から開く。件数が無ければチップを出さない', () => {
    const w = panel({ defaultOpen: true, count: undefined })
    expect(hidden(w)).toBe(false)
    expect(w.find('[data-testid="master-panel-count"]').exists()).toBe(false)
  })

  it('見出し（h3）が開閉ボタンを包み、button の中に見出しを置かない（HTML 適合）', () => {
    const w = panel()
    const toggle = w.find('[data-testid="master-panel-toggle"]')
    expect(toggle.element.closest('h3')).not.toBeNull()
    expect(toggle.find('h1,h2,h3,h4,h5,h6').exists()).toBe(false)
    expect(w.findAll('h3')).toHaveLength(1)
  })

  it('追加ボタンは開閉ボタンの外（入れ子にしない）。押しても開閉しない', async () => {
    const w = panel({}, true)
    const toggle = w.find('[data-testid="master-panel-toggle"]')
    expect(toggle.find('#act').exists()).toBe(false)
    expect(w.find('.master-panel__actions #act').exists()).toBe(true)
    await w.find('#act').trigger('click')
    expect(hidden(w)).toBe(true)
  })

  it('actions スロットが無ければ操作の枠を作らない', () => {
    expect(panel().find('.master-panel__actions').exists()).toBe(false)
  })
})

describe('MasterAddButton', () => {
  it('枠ボタン（outlined）＋プラスで、塗りの緑にしない。クリックを通す', async () => {
    const onClick = vi.fn()
    const w = mountIt(MasterAddButton, { props: { label: '特徴を追加', onClick } })
    expect(w.classes()).toContain('v-btn--variant-outlined')
    expect(w.classes()).not.toContain('bg-action')
    expect(w.find('.mdi-plus').exists()).toBe(true)
    expect(w.text()).toBe('特徴を追加')
    expect(w.attributes('aria-label')).toBe('特徴を追加')
    expect(w.attributes('style')).toContain('--v-theme-border-strong')
    await w.trigger('click')
    expect(onClick).toHaveBeenCalledOnce()
  })

  describe('スマホ幅（xs = 600px 未満）では + のアイコンだけにして、パネル名を省略させない', () => {
    const original = window.innerWidth
    afterEach(() => {
      window.innerWidth = original
    })
    const mountAt = (width: number, props: Record<string, unknown> = {}) => {
      window.innerWidth = width
      const w = mount(MasterAddButton, {
        props: { label: '特徴を追加', ...props },
        global: { plugins: [createVuetify({ components, directives }), i18n] },
      })
      wrappers.push(w as VueWrapper)
      return w
    }

    it('390px: 文字を出さず、名前は aria-label と title が持つ。枠ボタンのまま', () => {
      const w = mountAt(390, { text: '追加' })
      expect(w.text()).toBe('')
      expect(w.find('.mdi-plus').exists()).toBe(true)
      expect(w.attributes('aria-label')).toBe('特徴を追加')
      expect(w.attributes('title')).toBe('特徴を追加')
      expect(w.attributes('data-testid')).toBe('master-add')
      expect(w.classes()).toContain('v-btn--icon')
      expect(w.classes()).toContain('v-btn--variant-outlined')
      expect(w.classes()).not.toContain('bg-action')
      expect(w.attributes('style')).toContain('--v-theme-border-strong')
    })

    it('390px でもクリックを通す', async () => {
      const onClick = vi.fn()
      await mountAt(390, { onClick }).trigger('click')
      expect(onClick).toHaveBeenCalledOnce()
    })

    it('境界: 599px はアイコンのみ、600px と PC 幅は文字つき（title は付けない）', () => {
      expect(mountAt(599).text()).toBe('')
      for (const width of [600, 1280]) {
        const w = mountAt(width)
        expect(w.text()).toBe('特徴を追加')
        expect(w.classes()).not.toContain('v-btn--icon')
        expect(w.attributes('title')).toBeUndefined()
      }
    })
  })

  it('text を渡せば表示文字と aria-label を分けられる', () => {
    const w = mountIt(MasterAddButton, { props: { label: '特徴を追加', text: '追加' } })
    expect(w.text()).toBe('追加')
    expect(w.attributes('aria-label')).toBe('特徴を追加')
  })
})

describe('RowIconButton', () => {
  it('名前（aria-label と title）を持つ。編集は link、削除は danger-ink で、塗らない', async () => {
    const edit = mountIt(RowIconButton, { props: { icon: 'mdi-pencil', label: '先発を編集' } })
    expect(edit.attributes('aria-label')).toBe('先発を編集')
    expect(edit.attributes('title')).toBe('先発を編集')
    expect(edit.classes()).toContain('text-link')
    expect(edit.classes()).toContain('v-btn--variant-text')

    const del = mountIt(RowIconButton, {
      props: { icon: 'mdi-delete-outline', label: '先発を削除', danger: true },
    })
    await flushPromises()
    expect(del.classes()).toContain('text-danger-ink')
    expect(del.classes()).not.toContain('bg-danger-ink')
  })
})
