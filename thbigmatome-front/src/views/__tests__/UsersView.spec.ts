import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import UsersView from '../commissioner/UsersView.vue'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'

// Mock axios
vi.mock('axios', () => {
  const mockAxios = {
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
  }
  return { default: mockAxios }
})

vi.mock('@/plugins/axios', () => ({ default: {} }))

vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({ showSnackbar: vi.fn() }),
}))

import axios from 'axios'
import { stackedLayout } from '@/components/shared/__tests__/tableLayout'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState } },
})

describe('UsersView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: [] })
  })

  it('mounts successfully', async () => {
    const wrapper = mount(UsersView, { global: { plugins: [i18n, vuetify] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.1（画面タイトルはヘッダーバーが持つ。本文に置かない）
  it('画面タイトルを本文に持たず、骨格（PageLayout）で描く', async () => {
    const wrapper = mount(UsersView, { global: { plugins: [i18n, vuetify] } })
    await flushPromises()
    expect(wrapper.find('[data-testid="page-layout"]').exists()).toBe(true)
    expect(wrapper.find('h1').exists()).toBe(false)
    expect(wrapper.text()).not.toContain('ユーザー管理')
  })

  it('fetches users on mount', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: [{ id: 1, name: 'admin', display_name: '管理者', role: 'commissioner' }],
    })
    mount(UsersView, { global: { plugins: [i18n, vuetify] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/users')
  })

  // Test Basis: subtask_1787u 申し送り2 / thbig-dugout-visual-stage5-mapping.md §2 R3
  it('コミッショナーの tonal チップには link を使う', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: [{ id: 1, name: 'admin', display_name: '管理者', role: 'commissioner' }],
    })
    const wrapper = mount(UsersView, { global: { plugins: [i18n, vuetify] } })
    await flushPromises()
    const chips = wrapper
      .findAllComponents(components.VChip)
      .filter((chip) => chip.text() === 'コミッショナー')
    expect(chips).toHaveLength(1)
    expect(chips[0]!.props('color')).toBe('link')
    expect(chips[0]!.props('variant')).toBe('tonal')
  })

  describe('ロール変更', () => {
    const mockUser = { id: 2, name: 'user1', display_name: 'ユーザー1', role: 'player' as const }

    beforeEach(() => {
      ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: [mockUser] })
    })

    it('ロール変更成功時にsnackbarが表示される', async () => {
      const showSnackbar = vi.fn()
      vi.doMock('@/composables/useSnackbar', () => ({
        useSnackbar: () => ({ showSnackbar }),
      }))
      ;(axios.patch as ReturnType<typeof vi.fn>).mockResolvedValue({
        data: { ...mockUser, role: 'commissioner' },
      })

      const wrapper = mount(UsersView, { global: { plugins: [i18n, vuetify] } })
      await flushPromises()

      // submitRoleChange を直接呼び出して検証
      const vm = wrapper.vm as unknown as {
        openRoleDialog: (u: typeof mockUser) => void
        submitRoleChange: () => Promise<void>
        newRole: string
        roleChanging: boolean
      }
      vm.openRoleDialog(mockUser)
      vm.newRole = 'commissioner'
      await wrapper.vm.$nextTick()

      await vm.submitRoleChange()
      await flushPromises()

      expect(axios.patch).toHaveBeenCalledWith(`/users/${mockUser.id}/update_role`, {
        role: 'commissioner',
      })
    })

    it('ロール変更失敗時（422）にエラーsnackbarが表示される', async () => {
      ;(axios.patch as ReturnType<typeof vi.fn>).mockRejectedValue({
        response: { data: { error: '自分自身のロールは変更できません' } },
      })

      const wrapper = mount(UsersView, { global: { plugins: [i18n, vuetify] } })
      await flushPromises()

      const vm = wrapper.vm as unknown as {
        openRoleDialog: (u: typeof mockUser) => void
        submitRoleChange: () => Promise<void>
        newRole: string
      }
      vm.openRoleDialog(mockUser)
      vm.newRole = 'player'
      await wrapper.vm.$nextTick()

      await vm.submitRoleChange()
      await flushPromises()

      expect(axios.patch).toHaveBeenCalled()
    })

    it('openRoleDialog でダイアログが開く', async () => {
      const wrapper = mount(UsersView, { global: { plugins: [i18n, vuetify] } })
      await flushPromises()

      const vm = wrapper.vm as unknown as {
        openRoleDialog: (u: typeof mockUser) => void
        roleDialog: boolean
        roleTarget: typeof mockUser | null
        newRole: string
      }
      vm.openRoleDialog(mockUser)
      await wrapper.vm.$nextTick()

      expect(vm.roleDialog).toBe(true)
      expect(vm.roleTarget).toEqual(mockUser)
      expect(vm.newRole).toBe(mockUser.role)
    })

    it('closeRoleDialog でダイアログが閉じる', async () => {
      const wrapper = mount(UsersView, { global: { plugins: [i18n, vuetify] } })
      await flushPromises()

      const vm = wrapper.vm as unknown as {
        openRoleDialog: (u: typeof mockUser) => void
        closeRoleDialog: () => void
        roleDialog: boolean
      }
      vm.openRoleDialog(mockUser)
      await wrapper.vm.$nextTick()
      vm.closeRoleDialog()
      await wrapper.vm.$nextTick()

      expect(vm.roleDialog).toBe(false)
    })
  })
})

// Test Basis: thbig-dugout-ui-unification-design.md §2.5（<600px は縦積み。1 行 = 名前＋要点 2 つ＋操作）/ §4.2 段 4
describe('UsersView 表のスマホ対応（段 4）', () => {
  it('縦積み: ID=lead・ログインID=title・表示名=sub1・ロール=sub2・操作=act（操作は 2 つなのでアイコンのまま）', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: [{ id: 1, name: 'admin', display_name: '管理者', role: 'commissioner' }],
    })
    const wrapper = mount(UsersView, { global: { plugins: [i18n, vuetify] } })
    await flushPromises()
    expect(stackedLayout(wrapper)).toEqual({
      mobileBreakpoint: 'sm',
      rows: true,
      roles: { id: 'lead', name: 'title', display_name: 'sub1', role: 'sub2', actions: 'act' },
    })
    expect(wrapper.find('.row-menu').exists()).toBe(false)
  })
})
