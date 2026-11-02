import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import { createPinia } from 'pinia'
import TeamList from '../TeamList.vue'

vi.mock('vue-router', () => ({
  useRouter: () => ({
    push: vi.fn(),
  }),
}))

vi.mock('@/plugins/axios', () => ({
  default: {
    get: vi.fn(),
    delete: vi.fn(),
    defaults: {
      baseURL: '',
      withCredentials: false,
      headers: { common: {} },
    },
    interceptors: {
      request: { use: vi.fn() },
      response: { use: vi.fn() },
    },
  },
}))

vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({
    showSnackbar: vi.fn(),
  }),
}))

import axios from '@/plugins/axios'

enableAutoUnmount(afterEach)

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: {
    ja: {
      settings: {
        rowActions: { edit: '{name}を編集', delete: '{name}を削除' },
      },
      teamList: {
        title: 'チーム一覧',
        addTeam: 'チーム追加',
        noData: 'データなし',
        fetchFailed: '取得失敗',
        deleteSuccess: '削除成功',
        deleteFailed: '削除失敗',
        deleteConfirmTitle: '削除確認',
        deleteConfirmMessage: '削除しますか？',
        headers: {
          id: 'ID',
          name: '名前',
          shortName: '略称',
          teamType: '種別',
          managerName: '監督',
          isActive: '有効',
          lastGameRealDate: '最終実試合日',
          lastGameDate: '最終試合日',
          actions: '操作',
        },
        teamTypes: {
          hachinai: 'ハチナイ',
          normal: '通常',
        },
      },
      actions: {
        cancel: 'キャンセル',
        save: '保存',
      },
    },
  },
})

describe('TeamList', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(axios.get).mockResolvedValue({ data: [] })
  })

  it('チーム追加ボタン押下で TeamDialog に isVisible=true が渡る', async () => {
    const wrapper = mount(TeamList, {
      global: {
        plugins: [vuetify, i18n, createPinia()],
        stubs: {
          ConfirmDialog: true,
          TeamDialog: {
            name: 'TeamDialog',
            props: ['isVisible', 'team'],
            emits: ['update:isVisible', 'save'],
            template: '<div class="team-dialog-stub" />',
          },
        },
      },
    })

    await flushPromises()

    const dialog = wrapper.findComponent({ name: 'TeamDialog' })
    expect(dialog.props('isVisible')).toBe(false)

    const addButton = wrapper.findAllComponents({ name: 'VBtn' }).find((candidate) => {
      return candidate.text().includes('チーム追加')
    })

    expect(addButton).toBeDefined()
    await addButton!.trigger('click')
    await flushPromises()

    expect(dialog.props('isVisible')).toBe(true)
  })

  it('TeamDialog の update:isVisible を受けて閉じる', async () => {
    const wrapper = mount(TeamList, {
      global: {
        plugins: [vuetify, i18n, createPinia()],
        stubs: {
          ConfirmDialog: true,
          TeamDialog: {
            name: 'TeamDialog',
            props: ['isVisible', 'team'],
            emits: ['update:isVisible', 'save'],
            template: '<div class="team-dialog-stub" />',
          },
        },
      },
    })

    await flushPromises()

    const addButton = wrapper.findAllComponents({ name: 'VBtn' }).find((candidate) => {
      return candidate.text().includes('チーム追加')
    })

    expect(addButton).toBeDefined()
    await addButton!.trigger('click')
    await flushPromises()

    const dialog = wrapper.findComponent({ name: 'TeamDialog' })
    expect(dialog.props('isVisible')).toBe(true)

    await dialog.vm.$emit('update:isVisible', false)
    await flushPromises()

    expect(dialog.props('isVisible')).toBe(false)
  })

  // 破壊的な操作（削除）は danger-ink、ほかの行操作は link（塗らない）。R 規則の見た目
  it('行の削除ボタンは danger-ink、編集は link で、どちらも塗らない', async () => {
    vi.mocked(axios.get).mockResolvedValue({
      data: [
        {
          id: 1,
          name: '豊玉シャークス',
          short_name: '豊玉',
          team_type: 'normal',
          is_active: true,
          director: { name: '依田監督' },
        },
      ],
    })
    const wrapper = mount(TeamList, {
      global: {
        plugins: [vuetify, i18n, createPinia()],
        stubs: { ConfirmDialog: true, TeamDialog: true },
      },
    })
    await flushPromises()

    const button = (label: string) =>
      wrapper.findAllComponents({ name: 'VBtn' }).find((b) => b.attributes('aria-label') === label)
    const del = button('豊玉シャークスを削除')
    expect(del).toBeDefined()
    expect(del!.props('color')).toBe('danger-ink')
    expect(del!.props('variant')).toBe('text')
    const edit = button('豊玉シャークスを編集')
    expect(edit).toBeDefined()
    expect(edit!.props('color')).toBe('link')
    expect(edit!.props('variant')).toBe('text')
  })
})
