import { describe, it, expect, vi, afterEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import RowMenu from '../RowMenu.vue'

const vuetify = createVuetify({ components, directives })

// Test Basis: thbig-dugout-ui-unification-design.md §2.4（行の操作は 3 つ以上ならメニュー `mdi-dots-vertical`、aria-label・title 必須）
describe('RowMenu', () => {
  afterEach(() => {
    document.body.innerHTML = ''
  })

  const mountMenu = (onClick = vi.fn()) =>
    mount(RowMenu, {
      props: {
        label: '博麗霊夢の操作',
        items: [
          { icon: 'mdi-pencil', label: '編集', onClick },
          { icon: 'mdi-delete-outline', label: '削除', danger: true, onClick: vi.fn() },
        ],
      },
      global: { plugins: [vuetify] },
      attachTo: document.body,
    })

  it('開くボタンは mdi-dots-vertical で、aria-label と title に名前つきの操作名を持つ', () => {
    const wrapper = mountMenu()
    const btn = wrapper.find('[data-testid="row-menu"]')
    expect(btn.attributes('aria-label')).toBe('博麗霊夢の操作')
    expect(btn.attributes('title')).toBe('博麗霊夢の操作')
    expect(btn.html()).toContain('mdi-dots-vertical')
    wrapper.unmount()
  })

  it('押すと項目が出て、項目を選ぶとその操作が 1 回呼ばれる。開く前は項目を出さない', async () => {
    const onClick = vi.fn()
    const wrapper = mountMenu(onClick)
    expect(document.body.textContent).not.toContain('編集')
    await wrapper.find('[data-testid="row-menu"]').trigger('click')
    await flushPromises()
    const items = [...document.body.querySelectorAll('.v-list-item')]
    expect(items.map((i) => i.textContent?.trim())).toEqual(['編集', '削除'])
    ;(items[0] as HTMLElement).click()
    await flushPromises()
    expect(onClick).toHaveBeenCalledTimes(1)
    wrapper.unmount()
  })

  it('破壊的な項目は danger-ink（塗らない）', async () => {
    const wrapper = mountMenu()
    await wrapper.find('[data-testid="row-menu"]').trigger('click')
    await flushPromises()
    const items = [...document.body.querySelectorAll('.v-list-item')] as HTMLElement[]
    expect(items[1]!.className).toContain('text-danger-ink')
    expect(items[0]!.className).not.toContain('text-danger-ink')
    wrapper.unmount()
  })
})
