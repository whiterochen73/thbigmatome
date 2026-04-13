import { type Manager } from '@/types/manager'

export interface Team {
  id: number
  name: string
  short_name: string
  is_active: boolean
  has_season: boolean
  team_type: 'normal' | 'hachinai'
  user_id?: number | null
  director?: Manager
  coaches?: Manager[]
  last_game_real_date?: string | null
  last_game_date?: string | null
  season_current_date?: string | null
}
