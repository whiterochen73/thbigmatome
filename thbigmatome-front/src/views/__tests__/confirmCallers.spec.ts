import { expect, it, vi, beforeEach } from 'vitest'
import { mount, shallowMount, flushPromises } from '@vue/test-utils'
import { createI18n } from 'vue-i18n'
import { createPinia } from 'pinia'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import TeamList from '../TeamList.vue'
import Players from '../Players.vue'
import ManagerList from '../ManagerList.vue'
import GenericMasterSettings from '@/components/settings/GenericMasterSettings.vue'
import CommissionerDashboard from '@/components/commissioner/CommissionerDashboard.vue'

const { mockOpen, mockGet } = vi.hoisted(() => ({ mockOpen: vi.fn(), mockGet: vi.fn() }))
vi.mock('@/components/ConfirmDialog.vue', async () => {
  const { defineComponent } = await import('vue')
  return {
    default: defineComponent({
      name: 'ConfirmDialog',
      setup(_, { expose }) {
        expose({ open: mockOpen })
        return () => null
      },
    }),
  }
})
vi.mock('@/plugins/axios', () => ({
  default: { get: mockGet, delete: vi.fn(), defaults: { baseURL: '' } },
}))
vi.mock('axios', () => ({
  default: { get: mockGet, delete: vi.fn(), defaults: { baseURL: '' } },
}))
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => ({ params: {}, query: {} }),
  onBeforeRouteLeave: vi.fn(),
}))

const i18n = createI18n({ legacy: false, locale: 'ja', missingWarn: false, messages: { ja: {} } })
const vuetify = createVuetify({ components, directives })

beforeEach(() => {
  vi.clearAllMocks()
  mockOpen.mockResolvedValue(false)
  mockGet.mockImplementation((url: string) =>
    Promise.resolve({
      data:
        url === '/managers'
          ? { data: [], meta: { total_count: 0, current_page: 1, per_page: 25 } }
          : [],
    }),
  )
})

// Test Basis: thbig-dugout-visual-stage5-mapping.md §5.5, §7 b2-15〜b2-26 / subtask_1787r 申し送り3
it.each([
  ['TeamList', TeamList, 'deleteTeam'],
  ['Players', Players, 'deletePlayer'],
  ['ManagerList', ManagerList, 'deleteManager'],
  ['CommissionerDashboard', CommissionerDashboard, 'deleteTeam'],
] as const)('%s の削除確認は destructive を渡す', async (_name, component, method) => {
  const wrapper = mount(component, {
    global: { plugins: [vuetify, i18n, createPinia()], stubs: { ConfirmDialog: false } },
  })
  await flushPromises()
  await (wrapper.vm as unknown as Record<string, (id: number) => Promise<void>>)[method]!(1)
  expect(mockOpen).toHaveBeenCalledOnce()
  expect(mockOpen.mock.calls[0]?.[2]).toEqual({ destructive: true })
})

// Test Basis: thbig-dugout-visual-stage5-mapping.md §5.5, §7 b2-19 / subtask_1787r 申し送り3
it('GenericMasterSettings の削除確認は destructive を渡す', async () => {
  const wrapper = shallowMount(GenericMasterSettings, {
    props: {
      title: 'テスト',
      endpoint: '/items',
      i18nKey: 'items',
      dialogComponent: { template: '<div />' },
    },
    global: { plugins: [vuetify, i18n], stubs: { ConfirmDialog: false } },
  })
  await flushPromises()
  await (
    wrapper.vm as unknown as {
      confirmDelete: (item: { id: number; name: string }) => Promise<void>
    }
  ).confirmDelete({ id: 1, name: 'テスト' })
  expect(mockOpen).toHaveBeenCalledOnce()
  expect(mockOpen.mock.calls[0]?.[2]).toEqual({ destructive: true })
})
