import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createI18n } from 'vue-i18n'
import { createPinia } from 'pinia'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import TeamDialog from '../TeamDialog.vue'

vi.mock('@/plugins/axios', () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    patch: vi.fn(),
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
      actions: {
        cancel: 'キャンセル',
        save: '保存',
      },
      validation: {
        required: '必須です',
      },
      teamDialog: {
        title: {
          add: 'チーム追加',
          edit: 'チーム編集',
        },
        form: {
          name: '名前',
          shortName: '略称',
          director: '監督',
          teamType: '種別',
          teamTypeNormal: '通常',
          teamTypeHachinai: 'ハチナイ',
          teamTypeReadonly: '変更できません',
          isActive: '有効',
          directorAtCapacity: '上限到達',
        },
        notifications: {
          fetchManagersFailed: '監督一覧取得失敗',
          addSuccess: '追加成功',
          updateSuccess: '更新成功',
          saveFailed: '保存失敗',
          saveFailedWithErrors: '保存失敗: {errors}',
        },
      },
    },
  },
})

describe('TeamDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(axios.get).mockResolvedValue({
      data: {
        data: [
          {
            id: 1,
            name: '監督1',
            role: 'director',
            teams: [],
            active_director_team_count: 0,
          },
        ],
        meta: {
          total_count: 1,
          per_page: 1,
          current_page: 1,
          total_pages: 1,
        },
      },
    })
  })

  it('opens with all managers requested every time', async () => {
    const wrapper = mount(TeamDialog, {
      props: {
        isVisible: false,
        team: null,
        'onUpdate:isVisible': () => {},
      },
      global: {
        plugins: [vuetify, i18n, createPinia()],
      },
    })

    await wrapper.setProps({ isVisible: true })
    await flushPromises()

    expect(axios.get).toHaveBeenCalledWith('/managers', { params: { unpaginated: true } })

    vi.mocked(axios.get).mockClear()

    await wrapper.setProps({ isVisible: false })
    await wrapper.setProps({ isVisible: true })
    await flushPromises()

    expect(axios.get).toHaveBeenCalledTimes(1)
    expect(axios.get).toHaveBeenCalledWith('/managers', { params: { unpaginated: true } })
  })
})
