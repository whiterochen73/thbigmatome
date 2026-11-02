import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import TeamNameLink from '../TeamNameLink.vue'

// Test Basis: cmd_1814 チーム名を押せるようにする（見た目はリンク・キーボードで辿れる・説明文は付けない）
const mountLink = (props: Record<string, unknown> = {}, slots?: Record<string, string>) =>
  mount(TeamNameLink, {
    props: { teamId: 53, name: '豊玉', ...props },
    slots,
  })

describe('TeamNameLink', () => {
  it('チーム名を a 要素として出す（href は既定でそのチームのシーズン画面。キーボードの Enter でも辿れる）', () => {
    const link = mountLink().find('a')
    expect(link.exists()).toBe(true)
    expect(link.text()).toBe('豊玉')
    expect(link.attributes('href')).toBe('/teams/53/season')
    expect(link.classes()).toContain('team-name-link')
  })

  it('to を渡すと href がそのパスになる（相手の同じ日の試合日ページ・月指定のカレンダー）', () => {
    const link = mountLink({ to: '/teams/7/season/games/99' }).find('a')
    expect(link.attributes('href')).toBe('/teams/7/season/games/99')
  })

  it('スロットがあれば表示を差し替えられる（名前以外の見た目でも同じリンクにできる）', () => {
    const link = mountLink({}, { default: '<b>豊玉シャークス</b>' }).find('a')
    expect(link.text()).toBe('豊玉シャークス')
  })

  it('ふつうの左クリックは遷移せず、チームの id と名前で open を出す（移動は呼び出し側が選択中チームの切り替えと一緒に行う）', async () => {
    const wrapper = mountLink({ teamId: 7, name: '命懸' })
    const event = new MouseEvent('click', { bubbles: true, cancelable: true, button: 0 })
    wrapper.find('a').element.dispatchEvent(event)
    expect(event.defaultPrevented).toBe(true)
    expect(wrapper.emitted('open')).toEqual([[{ id: 7, name: '命懸' }]])
  })

  it('修飾キー付き・中クリックはブラウザに任せる（新しいタブで開ける。open は出さない）', async () => {
    const wrapper = mountLink()
    for (const init of [{ ctrlKey: true }, { metaKey: true }, { shiftKey: true }, { button: 1 }]) {
      const event = new MouseEvent('click', { bubbles: true, cancelable: true, ...init })
      wrapper.find('a').element.dispatchEvent(event)
      expect(event.defaultPrevented).toBe(false)
    }
    expect(wrapper.emitted('open')).toBeUndefined()
  })

  it('行ごと押せる表（行クリックで展開する表）で使えるよう、クリックを親へ伝えない', () => {
    let parentClicks = 0
    const wrapper = mount(TeamNameLink, {
      props: { teamId: 1, name: 'A' },
      attachTo: document.body,
    })
    const host = wrapper.element.parentElement!
    host.addEventListener('click', () => parentClicks++)
    wrapper
      .find('a')
      .element.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }))
    expect(parentClicks).toBe(0)
    wrapper.unmount()
  })
})
