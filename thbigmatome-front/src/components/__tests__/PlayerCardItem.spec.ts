import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import PlayerCardItem from '../PlayerCardItem.vue'

describe('PlayerCardItem.vue', () => {
  const vuetify = createVuetify()

  const mockCard = {
    id: 1,
    card_set_id: 1,
    player_id: 101,
    card_type: 'batter' as const,
    player_name: '野手太郎',
    player_number: '23',
    card_set_name: 'セット2026',
    speed: 4,
    steal_start: 15,
    steal_end: 20,
    injury_rate: 2,
    card_image_path: '/cards/player_101.jpg',
    cost: 8,
    defenses: [
      { position: 'SS', range_value: 3, error_rank: 'B', throwing: 'A' },
      { position: '2B', range_value: 2, error_rank: 'C', throwing: 'B' },
    ],
    unique_traits: 'スイッチ・盗塁',
  }

  it('カードコンポーネントが正しくレンダリングされる', () => {
    const wrapper = mount(PlayerCardItem, {
      props: {
        card: mockCard,
      },
      global: {
        plugins: [vuetify],
      },
    })

    expect(wrapper.find('.player-card').exists()).toBe(true)
  })

  it('選手名が表示される', () => {
    const wrapper = mount(PlayerCardItem, {
      props: {
        card: mockCard,
      },
      global: {
        plugins: [vuetify],
      },
    })

    const playerName = wrapper.find('.player-name')
    expect(playerName.text()).toBe('野手太郎')
  })

  it('背番号が表示される', () => {
    const wrapper = mount(PlayerCardItem, {
      props: {
        card: mockCard,
      },
      global: {
        plugins: [vuetify],
      },
    })

    const content = wrapper.text()
    expect(content).toContain('23')
  })

  it('種別チップが表示される', () => {
    const wrapper = mount(PlayerCardItem, {
      props: {
        card: mockCard,
      },
      global: {
        plugins: [vuetify],
      },
    })

    const chip = wrapper.find('[color="green"]')
    expect(chip.exists()).toBe(true)
    expect(chip.text()).toContain('野手')
  })

  it('投手の場合、種別が投手と表示される', () => {
    const pitcherCard = {
      ...mockCard,
      card_type: 'pitcher' as const,
    }

    const wrapper = mount(PlayerCardItem, {
      props: {
        card: pitcherCard,
      },
      global: {
        plugins: [vuetify],
      },
    })

    const chip = wrapper.find('[color="blue"]')
    expect(chip.exists()).toBe(true)
    expect(chip.text()).toContain('投手')
  })

  it('ポジションが表示される', () => {
    const wrapper = mount(PlayerCardItem, {
      props: {
        card: mockCard,
      },
      global: {
        plugins: [vuetify],
      },
    })

    const content = wrapper.text()
    expect(content).toContain('SS')
    expect(content).toContain('2B')
  })

  it('走力が表示される', () => {
    const wrapper = mount(PlayerCardItem, {
      props: {
        card: mockCard,
      },
      global: {
        plugins: [vuetify],
      },
    })

    const content = wrapper.text()
    expect(content).toContain('4')
  })

  it('clickイベントが発火する', async () => {
    const wrapper = mount(PlayerCardItem, {
      props: {
        card: mockCard,
      },
      global: {
        plugins: [vuetify],
      },
    })

    const card = wrapper.find('.player-card')
    await card.trigger('click')

    expect(wrapper.emitted('click')).toHaveLength(1)
  })

  it('カード画像がない場合、アイコンが表示される', () => {
    const cardNoImage = {
      ...mockCard,
      card_image_path: null,
    }

    const wrapper = mount(PlayerCardItem, {
      props: {
        card: cardNoImage,
      },
      global: {
        plugins: [vuetify],
      },
    })

    const noImage = wrapper.find('.no-image')
    expect(noImage.exists()).toBe(true)
  })
})
