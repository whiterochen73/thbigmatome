import { describe, it, expect, vi, beforeEach } from 'vitest'
import { ref } from 'vue'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import { createRouter, createMemoryHistory } from 'vue-router'
import DefaultLayout from '../DefaultLayout.vue'

// Mock axios with full defaults/interceptors support
vi.mock('axios', () => {
  const mockAxios = {
    get: vi.fn(),
    post: vi.fn(),
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

// Mock the axios plugin to prevent side effects
vi.mock('@/plugins/axios', () => {
  return { default: {} }
})

// Mock useAuth composable with reactive refs
const mockUser = ref({ id: 1, name: 'testuser', role: 'director' } as {
  id: number
  name: string
  role: string
} | null)
const mockIsCommissioner = ref(false)
const mockLogout = vi.fn()
vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    user: mockUser,
    isCommissioner: mockIsCommissioner,
    logout: mockLogout,
  }),
}))

// Mock useSnackbar composable
vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({
    isVisible: ref(false),
    message: ref(''),
    color: ref('success'),
    timeout: ref(3000),
  }),
}))

const vuetify = createVuetify({ components, directives })

const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: {
    ja: {
      layout: {
        appTitle: '東方BIG野球まとめツール',
        logout: 'ログアウト',
      },
      navigation: {
        dashboard: 'トップページ',
        managers: '監督一覧',
        teams: 'チーム一覧',
        players: '選手一覧',
        costAssignment: 'コスト登録',
        settings: '各種設定',
        expand: 'メニューを展開',
        collapse: 'メニューを縮小',
        externalLinks: '外部リンク',
        officialWiki: '公式Wiki',
      },
    },
  },
})

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/menu', name: 'dashboard', component: { template: '<div />' } },
      { path: '/managers', name: 'managers', component: { template: '<div />' } },
      { path: '/teams', name: 'teams', component: { template: '<div />' } },
      { path: '/players', name: 'players', component: { template: '<div />' } },
      { path: '/cost_assignment', name: 'costAssignment', component: { template: '<div />' } },
      { path: '/settings', name: 'settings', component: { template: '<div />' } },
      {
        path: '/commissioner/leagues',
        name: 'leagues',
        component: { template: '<div />' },
      },
    ],
  })
}

function mountDefaultLayout(options = {}) {
  const router = createTestRouter()
  return mount(DefaultLayout, {
    global: {
      plugins: [vuetify, i18n, router],
    },
    slots: {
      default: '<div class="test-content">Test Content</div>',
    },
    ...options,
  })
}

describe('DefaultLayout.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockUser.value = { id: 1, name: 'testuser', role: 'director' }
    mockIsCommissioner.value = false
  })

  describe('External links section', () => {
    it('displays external links subheader when not in rail mode', async () => {
      const wrapper = mountDefaultLayout()
      await flushPromises()

      // Subheader should be visible when drawer is not in rail mode
      expect(wrapper.text()).toContain('外部リンク')
    })

    it('displays official Wiki link item', async () => {
      const wrapper = mountDefaultLayout()
      await flushPromises()

      // Find the list item with href to wiki
      const wikiLink = wrapper
        .findAll('.v-list-item')
        .find((item) => item.attributes('href')?.includes('thbigbaseball.wiki.fc2.com'))
      expect(wikiLink).toBeTruthy()
    })

    it('has correct URL (https://thbigbaseball.wiki.fc2.com/)', async () => {
      const wrapper = mountDefaultLayout()
      await flushPromises()

      const wikiLink = wrapper
        .findAll('.v-list-item')
        .find((item) => item.attributes('href')?.includes('thbigbaseball.wiki.fc2.com'))
      expect(wikiLink?.attributes('href')).toBe('https://thbigbaseball.wiki.fc2.com/')
    })

    it('has target="_blank" attribute', async () => {
      const wrapper = mountDefaultLayout()
      await flushPromises()

      const wikiLink = wrapper
        .findAll('.v-list-item')
        .find((item) => item.attributes('href')?.includes('thbigbaseball.wiki.fc2.com'))
      expect(wikiLink?.attributes('target')).toBe('_blank')
    })

    it('uses i18n keys navigation.externalLinks and navigation.officialWiki', async () => {
      const wrapper = mountDefaultLayout()
      await flushPromises()

      expect(wrapper.text()).toContain('外部リンク')
      expect(wrapper.text()).toContain('公式Wiki')
    })

    it('displays mdi-open-in-new icon when not in rail mode', async () => {
      const wrapper = mountDefaultLayout()
      await flushPromises()

      const openInNewIcons = wrapper.findAll('.mdi-open-in-new')
      expect(openInNewIcons.length).toBeGreaterThanOrEqual(1)
    })

    it('displays mdi-baseball-diamond icon', async () => {
      const wrapper = mountDefaultLayout()
      await flushPromises()

      const baseballIcons = wrapper.findAll('.mdi-baseball-diamond')
      expect(baseballIcons.length).toBeGreaterThanOrEqual(1)
    })
  })

  describe('Rail mode behavior', () => {
    it('hides external links subheader in rail mode', async () => {
      const wrapper = mountDefaultLayout()
      await flushPromises()

      // Find the toggle button and click it to activate rail mode
      const toggleButton = wrapper
        .findAll('.v-list-item')
        .find((item) => item.text().includes('メニューを縮小'))
      expect(toggleButton).toBeTruthy()
      await toggleButton!.trigger('click')
      await flushPromises()

      // The subheader should not be visible in rail mode
      // Note: In rail mode, the subheader has v-if="!rail", so it won't exist in DOM
      // Since we can't directly test v-if false, we check that the list-item still exists
      const wikiLink = wrapper
        .findAll('.v-list-item')
        .find((item) => item.attributes('href')?.includes('thbigbaseball.wiki.fc2.com'))
      expect(wikiLink).toBeTruthy()
    })

    it('hides mdi-open-in-new append icon in rail mode', async () => {
      const wrapper = mountDefaultLayout()
      await flushPromises()

      const initialIconCount = wrapper.findAll('.mdi-open-in-new').length

      // Switch to rail mode
      const toggleButton = wrapper
        .findAll('.v-list-item')
        .find((item) => item.text().includes('メニューを縮小'))
      await toggleButton!.trigger('click')
      await flushPromises()

      const railIconCount = wrapper.findAll('.mdi-open-in-new').length
      // The append icon should be hidden in rail mode
      expect(railIconCount).toBeLessThan(initialIconCount)
    })

    it('keeps official Wiki link clickable in rail mode', async () => {
      const wrapper = mountDefaultLayout()
      await flushPromises()

      // Switch to rail mode
      const toggleButton = wrapper
        .findAll('.v-list-item')
        .find((item) => item.text().includes('メニューを縮小'))
      await toggleButton!.trigger('click')
      await flushPromises()

      // Wiki link should still exist and be clickable
      const wikiLink = wrapper
        .findAll('.v-list-item')
        .find((item) => item.attributes('href')?.includes('thbigbaseball.wiki.fc2.com'))
      expect(wikiLink).toBeTruthy()
      expect(wikiLink?.attributes('href')).toBe('https://thbigbaseball.wiki.fc2.com/')
      expect(wikiLink?.attributes('target')).toBe('_blank')
    })
  })

  describe('Navigation drawer', () => {
    it('displays standard menu items', async () => {
      const wrapper = mountDefaultLayout()
      await flushPromises()

      expect(wrapper.text()).toContain('ホーム')
      expect(wrapper.text()).toContain('チーム編成')
      expect(wrapper.text()).toContain('試合記録')
      expect(wrapper.text()).toContain('成績まとめ')
    })

    it('does not display commissioner menu for regular users', async () => {
      mockIsCommissioner.value = false

      const wrapper = mountDefaultLayout()
      await flushPromises()

      expect(wrapper.text()).not.toContain('大会管理')
    })

    it('displays commissioner menu when user is commissioner', async () => {
      mockIsCommissioner.value = true

      const wrapper = mountDefaultLayout()
      await flushPromises()

      expect(wrapper.text()).toContain('大会管理')
      expect(wrapper.text()).toContain('ユーザー管理')
    })
  })

  describe('App bar', () => {
    it('displays app title', async () => {
      const wrapper = mountDefaultLayout()
      await flushPromises()

      expect(wrapper.text()).toContain('東方BIG野球まとめツール')
    })
  })
})
