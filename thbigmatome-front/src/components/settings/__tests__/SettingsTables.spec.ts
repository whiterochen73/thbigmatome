import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import CostSettings from '../CostSettings.vue'
import ScheduleSettings from '../ScheduleSettings.vue'
import BattingStyleSettings from '../BattingStyleSettings.vue'
import BiorhythmSettings from '../BiorhythmSettings.vue'
import { chooseRowMenuItem, stackedLayout } from '@/components/shared/__tests__/tableLayout'

vi.mock('@/plugins/axios', () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))
vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({ showSnackbar: vi.fn() }),
}))
vi.mock('../CostDialog.vue', () => ({
  default: { name: 'CostDialog', props: ['modelValue', 'cost'], template: '<div />' },
}))
vi.mock('../ScheduleDialog.vue', () => ({
  default: { name: 'ScheduleDialog', props: ['modelValue', 'schedule'], template: '<div />' },
}))
vi.mock('../ScheduleDetailEditor.vue', () => ({
  default: { name: 'ScheduleDetailEditor', props: ['modelValue', 'schedule'], template: '<div />' },
}))

import axios from '@/plugins/axios'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState, settings: ja.settings, teamList: ja.teamList } },
})

const mountIt = async (component: object) => {
  const wrapper = mount(component, {
    attachTo: document.body,
    global: { plugins: [vuetify, i18n] },
  })
  await flushPromises()
  return wrapper
}

const route = (map: Record<string, unknown>) =>
  vi
    .mocked(axios.get)
    .mockImplementation((url: string) =>
      url in map
        ? map[url] instanceof Error
          ? Promise.reject(map[url])
          : Promise.resolve({ data: map[url] })
        : Promise.resolve({ data: [] }),
    )

// Test Basis: thbig-dugout-ui-unification-design.md §2.5（<600px は縦積み。1 行 = 名前＋要点 2 つ＋操作メニュー）/ §2.4（操作 3 つ以上はメニュー）/ §2.7（状態）/ §4.2 段 4
describe('設定のマスタ表（段 4）', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })
  afterEach(() => {
    document.body.innerHTML = ''
  })

  describe('コスト一覧表', () => {
    const cost = { id: 1, name: '2026コスト', start_date: '2026-01-01', end_date: null }

    it('縦積み: 名前=title・開始日=sub1（見出し付き）・終了日=sub2（見出し付き）・操作=act', async () => {
      route({ '/costs': [cost] })
      const wrapper = await mountIt(CostSettings)
      expect(stackedLayout(wrapper)).toEqual({
        mobileBreakpoint: 'sm',
        rows: true,
        roles: { name: 'title', start_date: 'sub1', end_date: 'sub2', actions: 'act' },
      })
      const cells = wrapper.findComponent({ name: 'VDataTable' }).props('headers') as {
        cellProps: { class: string }
      }[]
      expect(cells[1]!.cellProps.class).toContain('ui-cell--labeled')
      expect(cells[2]!.cellProps.class).toContain('ui-cell--labeled')
    })

    it('操作が 3 つ: PC はアイコン 3 つ、スマホは同じ操作の操作メニュー', async () => {
      route({ '/costs': [cost] })
      const wrapper = await mountIt(CostSettings)
      const full = wrapper.find('.row-actions.row-actions--full')
      expect(full.findAll('button').map((b) => b.attributes('aria-label'))).toEqual([
        '2026コストを編集',
        '2026コストを複製',
        '2026コストを削除',
      ])
      const menu = wrapper.find('.row-menu [data-testid="row-menu"]')
      expect(menu.attributes('aria-label')).toBe('2026コストの操作')
      await menu.trigger('click')
      await flushPromises()
      const items = [...document.body.querySelectorAll('.v-list-item')].map((i) =>
        i.textContent?.trim(),
      )
      expect(items).toEqual(['編集', '複製', '削除'])
    })

    it('取得中はスケルトン、0 件は空状態、失敗はアラート＋再読み込み（スケルトン・空と同時には出さない）', async () => {
      vi.mocked(axios.get).mockReturnValue(new Promise(() => {}))
      const loading = await mountIt(CostSettings)
      expect(loading.find('[data-testid="state-loading"]').exists()).toBe(true)
      expect(loading.find('[data-testid="state-empty"]').exists()).toBe(false)

      route({ '/costs': [] })
      const empty = await mountIt(CostSettings)
      expect(empty.find('[data-testid="state-empty"]').exists()).toBe(true)

      route({ '/costs': new Error('boom') })
      const failed = await mountIt(CostSettings)
      expect(failed.find('[data-testid="state-error"]').exists()).toBe(true)
      expect(failed.find('[data-testid="state-empty"]').exists()).toBe(false)
      route({ '/costs': [cost] })
      await failed.find('[data-testid="state-retry"]').trigger('click')
      await flushPromises()
      expect(failed.find('[data-testid="state-error"]').exists()).toBe(false)
      expect(failed.text()).toContain('2026コスト')
    })
  })

  describe('日程表', () => {
    const schedule = {
      id: 1,
      name: '2026日程',
      start_date: '2026-04-01',
      end_date: '2026-10-31',
      effective_date: '2026-03-01',
    }

    it('縦積み: 名前=title・開始日=sub1・終了日=sub2・適用日=note（いずれも見出し付き）・操作=act', async () => {
      route({ '/schedules': [schedule] })
      const wrapper = await mountIt(ScheduleSettings)
      expect(stackedLayout(wrapper)).toEqual({
        mobileBreakpoint: 'sm',
        rows: true,
        roles: {
          name: 'title',
          start_date: 'sub1',
          end_date: 'sub2',
          effective_date: 'note',
          actions: 'act',
        },
      })
    })

    it('操作が 3 つ: PC はアイコン、スマホは操作メニュー。失敗はアラート', async () => {
      route({ '/schedules': [schedule] })
      const wrapper = await mountIt(ScheduleSettings)
      expect(wrapper.find('.row-actions.row-actions--full').findAll('button')).toHaveLength(3)
      expect(wrapper.find('.row-menu [data-testid="row-menu"]').exists()).toBe(true)
      route({ '/schedules': new Error('boom') })
      const failed = await mountIt(ScheduleSettings)
      expect(failed.find('[data-testid="state-error"]').exists()).toBe(true)
    })
  })

  describe('汎用マスタ（GenericMasterSettings）', () => {
    it('バイオリズム: 名前=title・追加の列 2 つ=sub1・sub2。操作は 2 つなのでアイコンのまま（メニュー無し）', async () => {
      route({
        '/biorhythms': [{ id: 1, name: '周期A', start_date: '2026-04-01', end_date: '2026-09-30' }],
      })
      const wrapper = await mountIt(BiorhythmSettings)
      const layout = stackedLayout(wrapper)
      expect(layout.mobileBreakpoint).toBe('sm')
      expect(layout.rows).toBe(true)
      expect(layout.roles).toMatchObject({
        name: 'title',
        start_date: 'sub1',
        end_date: 'sub2',
        actions: 'act',
      })
      expect(wrapper.find('.row-menu').exists()).toBe(false)
      expect(wrapper.find('.row-actions').findAll('button')).toHaveLength(2)
    })

    it('説明の列は note。取得に失敗したらスナックバーでなくその場のアラート', async () => {
      route({ '/batting-styles': [{ id: 1, name: '引っ張り', description: '右へ引っ張る' }] })
      const ok = await mountIt(BattingStyleSettings)
      expect(stackedLayout(ok).roles).toMatchObject({ name: 'title', description: 'note' })

      route({ '/batting-styles': new Error('boom') })
      const failed = await mountIt(BattingStyleSettings)
      expect(failed.find('[data-testid="state-error"]').exists()).toBe(true)
      expect(failed.find('[data-testid="state-empty"]').exists()).toBe(false)
    })
  })
})

// Test Basis: 操作メニューの各項目は、PC のアイコンボタンと同じ操作を呼ぶ（項目の取り違えを固定する。subtask_1791u の warning）
describe('設定のマスタ表 操作メニューの各項目', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.stubGlobal(
      'confirm',
      vi.fn(() => true),
    )
    vi.mocked(axios.delete).mockResolvedValue({ data: {} })
    vi.mocked(axios.post).mockResolvedValue({ data: {} })
  })
  afterEach(() => {
    document.body.innerHTML = ''
    vi.unstubAllGlobals()
  })

  describe('コスト一覧表', () => {
    const open = async () => {
      vi.mocked(axios.get).mockResolvedValue({
        data: [{ id: 5, name: '2026コスト', start_date: '2026-01-01', end_date: null }],
      })
      const wrapper = mount(CostSettings, {
        attachTo: document.body,
        global: { plugins: [vuetify, i18n] },
      })
      await flushPromises()
      return wrapper
    }

    it('編集 → コストのダイアログをその行で開く（複製・削除は呼ばない）', async () => {
      const wrapper = await open()
      await chooseRowMenuItem(wrapper, '編集')
      const dialog = wrapper.findComponent({ name: 'CostDialog' })
      expect(dialog.props('modelValue')).toBe(true)
      expect((dialog.props('cost') as { id: number }).id).toBe(5)
      expect(axios.post).not.toHaveBeenCalled()
      expect(axios.delete).not.toHaveBeenCalled()
    })

    it('複製 → 確認のあとその行を複製する（POST。ダイアログ・削除は呼ばない）', async () => {
      const wrapper = await open()
      await chooseRowMenuItem(wrapper, '複製')
      expect(axios.post).toHaveBeenCalledWith('/costs/5/duplicate')
      expect(axios.delete).not.toHaveBeenCalled()
      expect(wrapper.findComponent({ name: 'CostDialog' }).props('modelValue')).toBe(false)
    })

    it('削除 → 確認のあとその行を DELETE する（複製・ダイアログは呼ばない）', async () => {
      const wrapper = await open()
      await chooseRowMenuItem(wrapper, '削除')
      expect(axios.delete).toHaveBeenCalledWith('/costs/5')
      expect(axios.post).not.toHaveBeenCalled()
      expect(wrapper.findComponent({ name: 'CostDialog' }).props('modelValue')).toBe(false)
    })
  })

  describe('日程表', () => {
    const open = async () => {
      vi.mocked(axios.get).mockResolvedValue({
        data: [
          {
            id: 9,
            name: '2026日程',
            start_date: '2026-04-01',
            end_date: '2026-10-31',
            effective_date: '2026-03-01',
          },
        ],
      })
      const wrapper = mount(ScheduleSettings, {
        attachTo: document.body,
        global: { plugins: [vuetify, i18n] },
      })
      await flushPromises()
      return wrapper
    }
    const opened = (wrapper: Awaited<ReturnType<typeof open>>) => ({
      detail: wrapper.findComponent({ name: 'ScheduleDetailEditor' }).props('modelValue'),
      edit: wrapper.findComponent({ name: 'ScheduleDialog' }).props('modelValue'),
    })

    it('日程を編集 → 日程の詳細エディタだけを開く', async () => {
      const wrapper = await open()
      await chooseRowMenuItem(wrapper, '日程を編集')
      expect(opened(wrapper)).toEqual({ detail: true, edit: false })
      expect(axios.delete).not.toHaveBeenCalled()
    })

    it('編集 → 日程表のダイアログだけを開く', async () => {
      const wrapper = await open()
      await chooseRowMenuItem(wrapper, '編集')
      expect(opened(wrapper)).toEqual({ detail: false, edit: true })
      expect(axios.delete).not.toHaveBeenCalled()
    })

    it('削除 → 確認のあとその行を DELETE する（ダイアログは開かない）', async () => {
      const wrapper = await open()
      await chooseRowMenuItem(wrapper, '削除')
      expect(axios.delete).toHaveBeenCalledWith('/schedules/9')
      expect(opened(wrapper)).toEqual({ detail: false, edit: false })
    })
  })
})
