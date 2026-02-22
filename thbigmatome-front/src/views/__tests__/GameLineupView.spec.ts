import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import GameLineupView from '../GameLineupView.vue'

// Mock axios
vi.mock('axios', () => {
  const mockAxios = {
    get: vi.fn(),
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

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: '42' } }),
  useRouter: () => ({ back: vi.fn() }),
}))

import axios from 'axios'

const vuetify = createVuetify({ components, directives })

const mockLineupData = {
  entries: [
    {
      id: 1,
      game_id: 42,
      player_id: 101,
      player_name: '博麗霊夢',
      batting_order: 1,
      position: 'CF',
      role: 'starter',
      is_dh_pitcher: false,
      is_reliever: false,
    },
    {
      id: 2,
      game_id: 42,
      player_id: 102,
      player_name: '霧雨魔理沙',
      batting_order: 2,
      position: 'P',
      role: 'starter',
      is_dh_pitcher: true,
      is_reliever: false,
    },
    {
      id: 3,
      game_id: 42,
      player_id: 103,
      player_name: '十六夜咲夜',
      batting_order: null,
      position: 'RP',
      role: 'bench',
      is_dh_pitcher: false,
      is_reliever: true,
    },
    {
      id: 4,
      game_id: 42,
      player_id: 104,
      player_name: '古明地こいし',
      batting_order: null,
      position: 'SS',
      role: 'off',
      is_dh_pitcher: false,
      is_reliever: false,
    },
    {
      id: 5,
      game_id: 42,
      player_id: 105,
      player_name: '東風谷早苗',
      batting_order: null,
      position: 'SP',
      role: 'designated_player',
      is_dh_pitcher: false,
      is_reliever: false,
    },
  ],
}

async function mountView() {
  ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: mockLineupData })
  const wrapper = mount(GameLineupView, {
    global: {
      plugins: [vuetify],
    },
  })
  await flushPromises()
  return wrapper
}

describe('GameLineupView.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('コンポーネントがマウントできる', async () => {
    const wrapper = await mountView()
    expect(wrapper.exists()).toBe(true)
  })

  it('正しいURLにAPIコールが行われる', async () => {
    await mountView()
    expect(axios.get).toHaveBeenCalledWith('/games/42/lineup')
  })

  it('スタメン選手が表示される', async () => {
    const wrapper = await mountView()
    const text = wrapper.text()
    expect(text).toContain('博麗霊夢')
    expect(text).toContain('霧雨魔理沙')
  })

  it('is_dh_pitcher=trueの選手にP/DHチップが表示される', async () => {
    const wrapper = await mountView()
    expect(wrapper.text()).toContain('P/DH')
  })

  it('ベンチ選手が表示される', async () => {
    const wrapper = await mountView()
    expect(wrapper.text()).toContain('十六夜咲夜')
  })

  it('is_reliever=trueのベンチ選手に（中継）が表示される', async () => {
    const wrapper = await mountView()
    expect(wrapper.text()).toContain('（中継）')
  })

  it('オフの選手が表示される', async () => {
    const wrapper = await mountView()
    expect(wrapper.text()).toContain('古明地こいし')
  })

  it('指定選手が表示され（指定）ラベルが付く', async () => {
    const wrapper = await mountView()
    expect(wrapper.text()).toContain('東風谷早苗')
    expect(wrapper.text()).toContain('（指定）')
  })
})
