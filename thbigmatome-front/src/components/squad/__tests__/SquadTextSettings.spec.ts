import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import SquadTextSettings from '../SquadTextSettings.vue'

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    put: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

import axios from 'axios'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: {
    ja: {
      squadTextSettings: {
        title: 'スカッドテキスト書式設定',
        positionFormat: 'ポジション表記',
        positionFormatEnglish: '英語略称',
        positionFormatJapanese: '漢字略称',
        handednessFormat: '投打表記',
        handednessFormatAlphabet: 'アルファベット',
        handednessFormatKanji: '漢字',
        dateFormat: '登板履歴日付',
        dateFormatAbsolute: '絶対日付',
        dateFormatRelative: '相対日付',
        sectionHeaderFormat: 'セクションヘッダー',
        sectionHeaderFormatBracket: '括弧付き',
        sectionHeaderFormatNone: '無印',
        showNumberPrefix: '背番号接頭辞',
        show: '表示する',
        hide: '表示しない',
        battingStatsItems: '打者成績項目',
        pitchingStatsItems: '投手成績項目',
        battingStats: {
          avg: '打率',
          hr: '本塁打',
          rbi: '打点',
          sb: '盗塁',
          obp: '出塁率',
          ops: 'OPS',
        },
        pitchingStats: {
          w_l: '勝敗',
          games: '登板数',
          era: '防御率',
          so: '奪三振',
          ip: '投球回',
          hold: 'ホールド',
          save: 'セーブ',
        },
        save: '保存',
        saved: '保存しました',
        saveError: '保存に失敗しました',
        loadError: '設定の読み込みに失敗しました',
      },
    },
  },
})

const mockSettingData = {
  id: 1,
  team_id: 10,
  position_format: 'english',
  handedness_format: 'alphabet',
  date_format: 'absolute',
  section_header_format: 'bracket',
  show_number_prefix: true,
  batting_stats_config: { avg: true, hr: true, rbi: true, sb: false, obp: false, ops: false },
  pitching_stats_config: {
    w_l: true,
    games: true,
    era: true,
    so: true,
    ip: true,
    hold: false,
    save: false,
  },
  updated_at: '2026-03-07T01:00:00.000Z',
}

function mountComponent() {
  return mount(SquadTextSettings, {
    props: { teamId: 10 },
    global: {
      plugins: [vuetify, i18n],
    },
  })
}

describe('SquadTextSettings', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('初期ロード', () => {
    it('マウント時にGETリクエストを送信する', async () => {
      vi.mocked(axios.get).mockResolvedValueOnce({ data: mockSettingData })
      mountComponent()
      expect(axios.get).toHaveBeenCalledWith('/teams/10/squad_text_settings')
    })

    it('タイトルが表示される', async () => {
      vi.mocked(axios.get).mockResolvedValueOnce({ data: mockSettingData })
      const wrapper = mountComponent()
      await flushPromises()
      expect(wrapper.text()).toContain('スカッドテキスト書式設定')
    })

    it('ロード後にポジション表記セクションが表示される', async () => {
      vi.mocked(axios.get).mockResolvedValueOnce({ data: mockSettingData })
      const wrapper = mountComponent()
      await flushPromises()
      expect(wrapper.text()).toContain('ポジション表記')
    })

    it('ロード後に投打表記セクションが表示される', async () => {
      vi.mocked(axios.get).mockResolvedValueOnce({ data: mockSettingData })
      const wrapper = mountComponent()
      await flushPromises()
      expect(wrapper.text()).toContain('投打表記')
    })

    it('ロード後に打者成績項目セクションが表示される', async () => {
      vi.mocked(axios.get).mockResolvedValueOnce({ data: mockSettingData })
      const wrapper = mountComponent()
      await flushPromises()
      expect(wrapper.text()).toContain('打者成績項目')
    })

    it('ロード後に投手成績項目セクションが表示される', async () => {
      vi.mocked(axios.get).mockResolvedValueOnce({ data: mockSettingData })
      const wrapper = mountComponent()
      await flushPromises()
      expect(wrapper.text()).toContain('投手成績項目')
    })

    it('ロード後に保存ボタンが表示される', async () => {
      vi.mocked(axios.get).mockResolvedValueOnce({ data: mockSettingData })
      const wrapper = mountComponent()
      await flushPromises()
      expect(wrapper.text()).toContain('保存')
    })
  })

  describe('設定の表示', () => {
    it('position_formatがenglishの場合、英語略称ラジオが選択される', async () => {
      vi.mocked(axios.get).mockResolvedValueOnce({
        data: { ...mockSettingData, position_format: 'english' },
      })
      const wrapper = mountComponent()
      await flushPromises()
      expect(wrapper.text()).toContain('英語略称')
    })

    it('各成績項目ラベルが表示される', async () => {
      vi.mocked(axios.get).mockResolvedValueOnce({ data: mockSettingData })
      const wrapper = mountComponent()
      await flushPromises()
      expect(wrapper.text()).toContain('打率')
      expect(wrapper.text()).toContain('本塁打')
      expect(wrapper.text()).toContain('打点')
      expect(wrapper.text()).toContain('防御率')
      expect(wrapper.text()).toContain('奪三振')
    })
  })

  describe('保存', () => {
    it('保存ボタンクリック時にPUTリクエストを送信する', async () => {
      vi.mocked(axios.get).mockResolvedValueOnce({ data: mockSettingData })
      vi.mocked(axios.put).mockResolvedValueOnce({ data: mockSettingData })
      const wrapper = mountComponent()
      await flushPromises()
      await wrapper.find('button').trigger('click')
      await flushPromises()
      expect(axios.put).toHaveBeenCalledWith(
        '/teams/10/squad_text_settings',
        expect.objectContaining({
          squad_text_setting: expect.objectContaining({
            position_format: 'english',
            handedness_format: 'alphabet',
          }),
        }),
      )
    })

    it('保存失敗時にsnackbarがエラー状態になる', async () => {
      vi.mocked(axios.get).mockResolvedValueOnce({ data: mockSettingData })
      vi.mocked(axios.put).mockRejectedValueOnce(new Error('Network Error'))
      const wrapper = mountComponent()
      await flushPromises()
      await wrapper.find('button').trigger('click')
      await flushPromises()
      const vm = wrapper.vm as { snackbar: { show: boolean; message: string; color: string } }
      expect(vm.snackbar.show).toBe(true)
      expect(vm.snackbar.color).toBe('error')
      expect(vm.snackbar.message).toContain('失敗')
    })
  })

  describe('GETエラー', () => {
    it('ロード失敗時にsnackbarがエラー状態になる', async () => {
      vi.mocked(axios.get).mockRejectedValueOnce(new Error('Network Error'))
      const wrapper = mountComponent()
      await flushPromises()
      const vm = wrapper.vm as { snackbar: { show: boolean; message: string; color: string } }
      expect(vm.snackbar.show).toBe(true)
      expect(vm.snackbar.color).toBe('error')
      expect(vm.snackbar.message).toContain('失敗')
    })
  })
})
