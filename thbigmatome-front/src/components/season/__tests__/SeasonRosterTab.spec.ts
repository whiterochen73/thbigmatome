import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import SeasonRosterTab from '../SeasonRosterTab.vue'
import { useSnackbar } from '@/composables/useSnackbar'

const { mockGet, mockPost } = vi.hoisted(() => ({ mockGet: vi.fn(), mockPost: vi.fn() }))

vi.mock('axios', () => ({
  default: {
    get: mockGet,
    post: mockPost,
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({ legacy: false, locale: 'ja', messages: { ja } })

// cmd_1783 段A: 保存結果を alert()（ブロッキング）ではなく、アプリ共通のスナックバーで知らせる
describe('SeasonRosterTab 保存結果の通知', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  beforeEach(() => {
    vi.clearAllMocks()
    mockGet.mockImplementation((url: string) =>
      url === '/teams/1/roster'
        ? Promise.resolve({
            data: { roster: [], season_id: 1, current_date: '2026-05-07', key_player_id: null },
          })
        : Promise.resolve({ data: [] }),
    )
  })

  async function mountTab() {
    const wrapper = mount(SeasonRosterTab, {
      props: { teamId: 1 },
      global: {
        plugins: [vuetify, i18n],
        stubs: { AbsenceInfo: true, PromotionCooldownInfo: true },
      },
    })
    await flushPromises()
    return wrapper
  }

  it('ロスターの保存に成功したら、スナックバー（success）で知らせ、alert は使わない', async () => {
    const alertSpy = vi.fn()
    vi.stubGlobal('alert', alertSpy)
    const wrapper = await mountTab()
    mockPost.mockResolvedValueOnce({ data: {} })

    await wrapper.vm.saveRoster()

    const { message, color } = useSnackbar()
    expect(message.value).toBe(ja.activeRoster.saveSuccess)
    expect(color.value).toBe('success')
    expect(alertSpy).not.toHaveBeenCalled()
  })

  it('ロスターの保存に失敗したら、サーバのエラー文を添えてスナックバー（error）で知らせる', async () => {
    const alertSpy = vi.fn()
    vi.stubGlobal('alert', alertSpy)
    vi.spyOn(console, 'error').mockImplementation(() => {})
    const wrapper = await mountTab()
    mockPost.mockRejectedValueOnce({ response: { data: { error: '1軍が上限を超えています' } } })

    await wrapper.vm.saveRoster()

    const { message, color } = useSnackbar()
    expect(message.value).toBe(`${ja.activeRoster.saveFailed}: 1軍が上限を超えています`)
    expect(color.value).toBe('error')
    expect(alertSpy).not.toHaveBeenCalled()
  })

  it('特例選手の保存も同じスナックバーで知らせる（成功・失敗）', async () => {
    const alertSpy = vi.fn()
    vi.stubGlobal('alert', alertSpy)
    vi.spyOn(console, 'error').mockImplementation(() => {})
    const wrapper = await mountTab()
    const { message, color } = useSnackbar()

    mockPost.mockResolvedValueOnce({ data: {} })
    await wrapper.vm.saveKeyPlayer()
    expect(message.value).toBe(ja.activeRoster.keyPlayerSaveSuccess)
    expect(color.value).toBe('success')

    mockPost.mockRejectedValueOnce(new Error('network'))
    await wrapper.vm.saveKeyPlayer()
    expect(message.value).toBe(`${ja.activeRoster.keyPlayerSaveFailed}: network`)
    expect(color.value).toBe('error')
    expect(alertSpy).not.toHaveBeenCalled()
  })
})
