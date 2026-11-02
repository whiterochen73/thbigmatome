import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { ja } from 'vuetify/locale'
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

// 前のテストの画面が生き残ると、その取得も数に入る
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
      // 初回の取得は 1 回（空の間は表を描かないので、表からの取得通知は来ない）
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

describe('ManagerList の件数とページング', () => {
  // 25 人 / ページで総数 35 人の応答
  const manager = (id: number) => ({
    id,
    name: `監督${id}`,
    short_name: `監${id}`,
    irc_name: `mgr${id}`,
    user_id: id,
    active_director_team_count: 0,
    teams: [],
  })
  const page1 = () => ({
    data: {
      data: Array.from({ length: 25 }, (_, i) => manager(35 - i)),
      meta: { total_count: 35, current_page: 1, per_page: 25 },
    },
  })
  // 本番と同じ日本語の件数表示（'1-25 件目 / 35件'）で確かめる
  const vuetifyJa = createVuetify({
    components,
    directives,
    locale: { locale: 'ja', messages: { ja } },
  })
  beforeEach(() => {
    // 前のテストの mockResolvedValueOnce の残りを持ち込まない
    vi.mocked(axios.get).mockReset()
  })
  const mountList = async () => {
    const wrapper = mount(ManagerList, {
      global: {
        plugins: [vuetifyJa, i18n, createPinia()],
        stubs: { TeamDialog: true, ConfirmDialog: true },
      },
    })
    await flushPromises()
    return wrapper
  }
  const vmOf = (w: Awaited<ReturnType<typeof mountList>>) =>
    w.vm as unknown as { onOptionsUpdate: (o: { page: number; itemsPerPage: number }) => void }

  it('総件数（サーバの total_count）を件数表示に使う: 25 件しか持っていなくても 35 件と出す', async () => {
    vi.mocked(axios.get).mockResolvedValue(page1())
    const wrapper = await mountList()
    const footer = wrapper.find('.v-data-table-footer').text()
    expect(footer).toContain('1-25 件目 / 35件')
  })

  it('次のページへ進めて、押すと 2 ページ目を取りに行く', async () => {
    vi.mocked(axios.get).mockResolvedValue(page1())
    const wrapper = await mountList()
    const next = wrapper.find('.v-data-table-footer button[aria-label="次のページ"]')
    expect(next.exists()).toBe(true)
    expect(next.attributes('disabled')).toBeUndefined()
    await next.trigger('click')
    await flushPromises()
    expect(axios.get).toHaveBeenLastCalledWith('/managers', { params: { page: 2, per_page: 25 } })
  })

  it('取得済みと同じ条件の更新通知では取り直さない', async () => {
    vi.mocked(axios.get).mockResolvedValue(page1())
    const wrapper = await mountList()
    expect(axios.get).toHaveBeenCalledTimes(1)
    vmOf(wrapper).onOptionsUpdate({ page: 1, itemsPerPage: 25 })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledTimes(1)
  })

  it('ページ番号が違えば取り直す', async () => {
    vi.mocked(axios.get).mockResolvedValue(page1())
    const wrapper = await mountList()
    vmOf(wrapper).onOptionsUpdate({ page: 2, itemsPerPage: 25 })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledTimes(2)
    expect(axios.get).toHaveBeenLastCalledWith('/managers', { params: { page: 2, per_page: 25 } })
  })

  it('1 ページの件数が違えば（ページ番号が同じでも）取り直す', async () => {
    vi.mocked(axios.get).mockResolvedValue(page1())
    const wrapper = await mountList()
    vmOf(wrapper).onOptionsUpdate({ page: 1, itemsPerPage: 50 })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledTimes(2)
    expect(axios.get).toHaveBeenLastCalledWith('/managers', { params: { page: 1, per_page: 50 } })
  })

  it('2 ページ目の件数表示は 26-35 件目。保存して 1 ページ目へ戻ると表も 1 ページ目に戻る', async () => {
    vi.mocked(axios.get)
      .mockResolvedValueOnce(page1())
      .mockResolvedValueOnce({
        data: {
          data: Array.from({ length: 10 }, (_, i) => manager(10 - i)),
          meta: { total_count: 35, current_page: 2, per_page: 25 },
        },
      })
      .mockResolvedValueOnce({
        data: {
          data: Array.from({ length: 25 }, (_, i) => manager(36 - i)),
          meta: { total_count: 36, current_page: 1, per_page: 25 },
        },
      })
    const wrapper = await mountList()
    vmOf(wrapper).onOptionsUpdate({ page: 2, itemsPerPage: 25 })
    await flushPromises()
    expect(wrapper.find('.v-data-table-footer').text()).toContain('26-35 件目 / 35件')
    ;(wrapper.vm as unknown as { handleManagerSaved: () => void }).handleManagerSaved()
    await flushPromises()
    expect(wrapper.find('.v-data-table-footer').text()).toContain('1-25 件目 / 36件')
    // 表が戻る時の更新通知で、同じ 1 ページ目をもう一度取りに行かない
    expect(axios.get).toHaveBeenCalledTimes(3)
  })
})
