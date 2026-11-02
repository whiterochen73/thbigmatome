// Test Basis: thbig-dugout-visual-refresh-design.md §6.1 / §6.5; subtask_1783t Operator 指摘 3
export function dateTypeAppearance(dateType?: string | null): {
  color: string
  icon: string
  category: string
  cancelled: boolean
} {
  switch (dateType) {
    case 'game_day':
      return {
        color: 'date-game',
        icon: 'mdi-baseball-diamond',
        category: 'game',
        cancelled: false,
      }
    case 'playoff_day':
      return { color: 'date-game', icon: 'mdi-trophy', category: 'game', cancelled: false }
    case 'interleague_game_day':
      return {
        color: 'date-interleague',
        icon: 'mdi-swap-horizontal',
        category: 'inter',
        cancelled: false,
      }
    case 'interleague_reserve_day':
      return {
        color: 'date-interleague',
        icon: 'mdi-swap-horizontal',
        category: 'inter-reserve',
        cancelled: false,
      }
    case 'reserve_day':
      return {
        color: 'date-reserve',
        icon: 'mdi-calendar-clock',
        category: 'reserve',
        cancelled: false,
      }
    case 'travel_day':
      return { color: 'date-travel', icon: 'mdi-bus', category: 'travel', cancelled: false }
    case 'no_game':
    case 'postponed':
      return {
        color: 'date-rain',
        icon: 'mdi-weather-pouring',
        category: 'no-game',
        cancelled: true,
      }
    default:
      return {
        color: 'state-neutral',
        icon: 'mdi-minus-circle-outline',
        category: 'off',
        cancelled: false,
      }
  }
}
