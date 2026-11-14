import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import axios from 'axios'
import PlayerNameLink from '../PlayerNameLink.vue'

vi.mock('axios')

// Test Basis: cmd_1901。同じ選手に複数のカード（旧セット・エイプリル・チーム名の完走カード）があるので、
// 名前にカーソルを置いた時の画像は、登録されているカードそのもの。分からない時は現行セットの通常カードを選び、先頭の 1 枚を使わない。
const vuetify = createVuetify({ components, directives })
const router = createRouter({
  history: createMemoryHistory(),
  routes: [{ path: '/', component: { template: '<div />' } }],
})

const card = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  image_url: `https://example.test/${id}.png`,
  card_set_current: true,
  official_use_prohibited: false,
  version_label: null,
  ...over,
})

let nextPlayerId = 1000
async function hover(props: Record<string, unknown>) {
  const wrapper = mount(PlayerNameLink, {
    props: { playerId: nextPlayerId++, playerName: '八雲 紫', ...props },
    global: { plugins: [vuetify, router] },
  })
  await wrapper.find('.player-name-link').trigger('mouseenter')
  await flushPromises()
  return wrapper.vm as unknown as { resolvedImageUrl: string | null }
}

describe('PlayerNameLink のホバー画像', () => {
  beforeEach(() => {
    vi.mocked(axios.get).mockReset()
  })

  it('登録されているカードが分かる時は、そのカードの画像（選手の別のカードを引かない）', async () => {
    vi.mocked(axios.get).mockResolvedValue({ data: card(7, { variant: '飯能' }) })
    const vm = await hover({ playerCardId: 7 })
    expect(axios.get).toHaveBeenCalledTimes(1)
    expect(axios.get).toHaveBeenCalledWith('/player_cards/7')
    expect(vm.resolvedImageUrl).toBe('https://example.test/7.png')
  })

  it('カードが分からない時は、旧セットの先頭ではなく現行セットの通常カード（印なし）を選ぶ', async () => {
    vi.mocked(axios.get).mockResolvedValue({
      data: {
        player_cards: [
          card(1, { card_set_current: false }),
          card(2, { version_label: 'エイプリル' }),
          card(3),
        ],
      },
    })
    const vm = await hover({})
    expect(vm.resolvedImageUrl).toBe('https://example.test/3.png')
  })

  it('現行セットの通常カードが無ければ、現行セットの別の版（公式戦で使えるもの）', async () => {
    vi.mocked(axios.get).mockResolvedValue({
      data: {
        player_cards: [
          card(1, { card_set_current: false }),
          card(2, { version_label: 'UR', official_use_prohibited: true }),
          card(3, { version_label: '飯能' }),
        ],
      },
    })
    const vm = await hover({})
    expect(vm.resolvedImageUrl).toBe('https://example.test/3.png')
  })

  it('現行のカードが 1 枚も無ければ先頭。画像の無いカードは画像なしのまま（別のカードの画像で埋めない）', async () => {
    vi.mocked(axios.get).mockResolvedValue({
      data: {
        player_cards: [
          card(1, { card_set_current: false, image_url: null }),
          card(2, { card_set_current: false }),
        ],
      },
    })
    const vm = await hover({})
    expect(vm.resolvedImageUrl).toBeNull()
  })
})
