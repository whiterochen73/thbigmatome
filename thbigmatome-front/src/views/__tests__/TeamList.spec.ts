import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
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

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: {
    ja: {
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
          PageHeader: {
            template:
              '<div><slot /><div data-testid="page-header-actions"><slot name="actions" /></div></div>',
          },
          DataCard: { template: '<div><slot /></div>' },
          FilterBar: { template: '<div />' },
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
          PageHeader: {
            template:
              '<div><slot /><div data-testid="page-header-actions"><slot name="actions" /></div></div>',
          },
          DataCard: { template: '<div><slot /></div>' },
          FilterBar: { template: '<div />' },
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
})
