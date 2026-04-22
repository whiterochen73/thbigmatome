import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import { createPinia } from 'pinia'
import ManagerList from '../ManagerList.vue'
import ManagerDialog from '@/components/ManagerDialog.vue'

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
      actions: {
        cancel: 'キャンセル',
        save: '保存',
      },
      managerList: {
        title: '監督一覧',
        addManager: '監督追加',
        noData: 'データなし',
        fetchFailed: '取得失敗',
        deleteSuccess: '削除成功',
        deleteFailed: '削除失敗',
        deleteConfirmTitle: '削除確認',
        deleteConfirmMessage: '削除しますか？',
        atCapacity: '上限',
        headers: {
          id: 'ID',
          name: '名前',
          shortName: '略称',
          ircName: 'IRC名',
          userId: 'ユーザーID',
          teamCount: '担当数',
          actions: '操作',
        },
        expanded: {
          title: '担当チーム',
          addTeam: 'チーム追加',
          active: '有効',
          inactive: '無効',
          noTeams: 'チームなし',
        },
      },
      managerDialog: {
        title: {
          add: '監督追加',
          edit: '監督編集',
        },
        form: {
          name: '名前',
          shortName: '略称',
          ircName: 'IRC名',
          userId: 'ユーザーID',
        },
        validation: {
          required: '必須です',
        },
        notifications: {
          addSuccess: '追加成功',
          updateSuccess: '更新成功',
          saveFailed: '保存失敗',
          saveFailedWithErrors: '保存失敗: {errors}',
        },
      },
    },
  },
})

describe('ManagerList', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(axios.get).mockResolvedValue({
      data: {
        data: [],
        meta: {
          total_count: 0,
          current_page: 1,
          per_page: 25,
        },
      },
    })
  })

  it('監督追加ボタン押下で ManagerDialog が開く', async () => {
    const wrapper = mount(ManagerList, {
      global: {
        plugins: [vuetify, i18n, createPinia()],
        stubs: {
          TeamDialog: true,
          ConfirmDialog: true,
        },
      },
    })

    await flushPromises()

    const dialog = wrapper.findComponent(ManagerDialog)
    expect(dialog.props('isVisible')).toBe(false)

    const addButton = wrapper.findAllComponents({ name: 'VBtn' }).find((candidate) => {
      return candidate.text().includes('監督追加')
    })

    expect(addButton).toBeDefined()
    await addButton!.trigger('click')
    await flushPromises()

    expect(dialog.props('isVisible')).toBe(true)
  })

  it('監督追加ダイアログで保存すると一覧が再取得される', async () => {
    vi.mocked(axios.get)
      .mockResolvedValueOnce({
        data: {
          data: [],
          meta: {
            total_count: 0,
            current_page: 1,
            per_page: 25,
          },
        },
      })
      .mockResolvedValueOnce({
        data: {
          data: [],
          meta: {
            total_count: 0,
            current_page: 1,
            per_page: 25,
          },
        },
      })
      .mockResolvedValueOnce({
        data: {
          data: [
            {
              id: 99,
              name: 'テスト監督',
              short_name: 'テスト',
              irc_name: 'test_mgr',
              user_id: 123,
              active_director_team_count: 0,
              teams: [],
            },
          ],
          meta: {
            total_count: 1,
            current_page: 1,
            per_page: 25,
          },
        },
      })
    vi.mocked(axios.delete).mockResolvedValue({})
    vi.mocked(axios.get).mockName('axios.get')
    ;(axios as unknown as { post?: ReturnType<typeof vi.fn> }).post = vi.fn().mockResolvedValue({
      data: {
        data: {
          id: 99,
        },
      },
    })

    const wrapper = mount(ManagerList, {
      global: {
        plugins: [vuetify, i18n, createPinia()],
        stubs: {
          TeamDialog: true,
          ConfirmDialog: true,
        },
      },
    })

    await flushPromises()

    const addButton = wrapper.findAllComponents({ name: 'VBtn' }).find((candidate) => {
      return candidate.text().includes('監督追加')
    })

    expect(addButton).toBeDefined()
    await addButton!.trigger('click')
    await flushPromises()

    const dialogVm = wrapper.findComponent(ManagerDialog).vm as unknown as {
      editedManager: {
        name: string
        short_name: string
        irc_name: string
        user_id: number | null
      }
      save: () => Promise<void>
    }

    dialogVm.editedManager.name = 'テスト監督'
    dialogVm.editedManager.short_name = 'テスト'
    dialogVm.editedManager.irc_name = 'test_mgr'
    dialogVm.editedManager.user_id = 123

    await dialogVm.save()
    await flushPromises()

    expect((axios as unknown as { post: ReturnType<typeof vi.fn> }).post).toHaveBeenCalledWith(
      '/managers',
      {
        manager: expect.objectContaining({
          name: 'テスト監督',
          short_name: 'テスト',
          irc_name: 'test_mgr',
          user_id: 123,
        }),
      },
    )
    expect(axios.get.mock.calls.length).toBeGreaterThanOrEqual(2)
    expect(wrapper.text()).toContain('テスト監督')
  })

  it('監督保存後は1ページ目を再取得する', async () => {
    vi.mocked(axios.get)
      .mockResolvedValueOnce({
        data: {
          data: [],
          meta: {
            total_count: 30,
            current_page: 1,
            per_page: 25,
          },
        },
      })
      .mockResolvedValueOnce({
        data: {
          data: [],
          meta: {
            total_count: 30,
            current_page: 2,
            per_page: 25,
          },
        },
      })
      .mockResolvedValueOnce({
        data: {
          data: [
            {
              id: 101,
              name: '最新監督',
              short_name: '最新',
              irc_name: 'latest_mgr',
              user_id: 456,
              active_director_team_count: 0,
              teams: [],
            },
          ],
          meta: {
            total_count: 31,
            current_page: 1,
            per_page: 25,
          },
        },
      })
    ;(axios as unknown as { post?: ReturnType<typeof vi.fn> }).post = vi.fn().mockResolvedValue({
      data: {
        data: {
          id: 101,
        },
      },
    })

    const wrapper = mount(ManagerList, {
      global: {
        plugins: [vuetify, i18n, createPinia()],
        stubs: {
          TeamDialog: true,
          ConfirmDialog: true,
        },
      },
    })

    await flushPromises()

    const vm = wrapper.vm as unknown as {
      onOptionsUpdate: (options: { page: number; itemsPerPage: number }) => void
    }
    vm.onOptionsUpdate({ page: 2, itemsPerPage: 25 })
    await flushPromises()

    const addButton = wrapper.findAllComponents({ name: 'VBtn' }).find((candidate) => {
      return candidate.text().includes('監督追加')
    })

    expect(addButton).toBeDefined()
    await addButton!.trigger('click')
    await flushPromises()

    const dialogVm = wrapper.findComponent(ManagerDialog).vm as unknown as {
      editedManager: {
        name: string
        short_name: string
        irc_name: string
        user_id: number | null
      }
      save: () => Promise<void>
    }

    dialogVm.editedManager.name = '最新監督'
    dialogVm.editedManager.short_name = '最新'
    dialogVm.editedManager.irc_name = 'latest_mgr'
    dialogVm.editedManager.user_id = 456

    await dialogVm.save()
    await flushPromises()

    expect(axios.get).toHaveBeenLastCalledWith('/managers', {
      params: { page: 1, per_page: 25 },
    })
  })
})
