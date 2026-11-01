import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import AsyncState from '../AsyncState.vue'
import ja from '@/locales/ja.json'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({ legacy: false, locale: 'ja', messages: { ja } })

const mountState = (props: Record<string, unknown> = {}, slots: Record<string, string> = {}) =>
  mount(AsyncState, {
    props: { emptyMessage: '選手が登録されていません', ...props },
    slots: { default: '<div id="content">内容</div>', ...slots },
    global: { plugins: [vuetify, i18n] },
  })

const exists = (w: ReturnType<typeof mountState>, id: string) =>
  w.find(`[data-testid="${id}"]`).exists()

// Test Basis: thbig-dugout-ui-unification-design.md §2.7（読み込み=スケルトン / 空=EmptyState / 失敗=アラート＋再読み込み）
describe('AsyncState', () => {
  it('内容がある時は内容だけを出す', () => {
    const w = mountState({ empty: false })
    expect(w.find('#content').exists()).toBe(true)
    expect(exists(w, 'state-loading')).toBe(false)
    expect(exists(w, 'state-empty')).toBe(false)
    expect(exists(w, 'state-error')).toBe(false)
    expect(exists(w, 'state-refreshing')).toBe(false)
  })

  it('初回の読み込み中（内容が無い）はスケルトンを出し、空状態を出さない', () => {
    const w = mountState({ loading: true, empty: true })
    expect(exists(w, 'state-loading')).toBe(true)
    expect(exists(w, 'state-empty')).toBe(false)
    expect(w.find('#content').exists()).toBe(false)
    expect(w.attributes('aria-busy')).toBe('true')
  })

  it('読み込みが終わって空なら空状態（アイコン＋文言＋あれば操作）を出す', () => {
    const w = mountState(
      { empty: true, emptyIcon: 'mdi-account-off-outline' },
      { 'empty-actions': '<button id="act">追加</button>' },
    )
    expect(exists(w, 'state-loading')).toBe(false)
    const empty = w.find('[data-testid="state-empty"]')
    expect(empty.text()).toContain('選手が登録されていません')
    expect(empty.find('.mdi-account-off-outline').exists()).toBe(true)
    expect(empty.find('#act').exists()).toBe(true)
    expect(w.find('#content').exists()).toBe(false)
  })

  it('再取得中は前の内容を消さず、細い進捗線だけを出す', () => {
    const w = mountState({ loading: true, empty: false })
    expect(w.find('#content').exists()).toBe(true)
    expect(exists(w, 'state-refreshing')).toBe(true)
    expect(exists(w, 'state-loading')).toBe(false)
  })

  it('失敗したらアラートと再読み込みを出し、空状態は出さない。再読み込みで retry を通知する', async () => {
    const w = mountState({
      error: true,
      empty: true,
      errorMessage: '選手一覧の取得に失敗しました。',
    })
    const alert = w.find('[data-testid="state-error"]')
    expect(alert.text()).toContain('選手一覧の取得に失敗しました。')
    expect(exists(w, 'state-empty')).toBe(false)
    expect(exists(w, 'state-loading')).toBe(false)
    await w.find('[data-testid="state-retry"]').trigger('click')
    expect(w.emitted('retry')).toHaveLength(1)
  })

  it('文言を渡さなければ既定の失敗文言と「再読み込み」を使う', () => {
    const w = mountState({ error: true, empty: true })
    expect(w.find('[data-testid="state-error"]').text()).toContain('読み込みに失敗しました。')
    expect(w.find('[data-testid="state-retry"]').text()).toContain('再読み込み')
  })

  it('失敗しても前の内容があれば、アラートの下に内容を残す', () => {
    const w = mountState({ error: true, empty: false })
    expect(exists(w, 'state-error')).toBe(true)
    expect(w.find('#content').exists()).toBe(true)
  })

  it('framed の時だけ、スケルトンと空状態を縁つきの枠で包むクラスを付ける', () => {
    expect(mountState({ empty: true }).classes()).not.toContain('async-state--framed')
    expect(mountState({ empty: true, framed: true }).classes()).toContain('async-state--framed')
  })
})
