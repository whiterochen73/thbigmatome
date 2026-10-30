export interface LineupItem {
  player_id: number
  position: string
  order: number
}

export type GameVenue = 'ch1' | 'ch2' | 'ch3' | 'ch4' | 'ch5' | 'tlb'

export interface GameData {
  team_id: number
  team_name: string
  season_id: number
  game_date: string
  game_number: number
  announced_starter_id: number | null
  competition_id?: number | null
  // ゲーム内の球場（甲子園・神宮など）。開催球場（venue）とは別
  stadium: string
  // 試合をするリアルの日付（YYYY-MM-DD）・大まかな開始時刻（30 分刻みの HH:MM）・開催球場（IRC のチャンネル）。いずれも任意
  real_date: string | null
  real_start_time: string | null
  venue: GameVenue | null
  // 試合ログの原文（保存するだけで解析はしない。上限 1MB）
  game_log: string | null
  home_away: 'home' | 'visitor' | null
  designated_hitter_enabled: boolean | null
  opponent_team_id: number | null
  opponent_team_name: string
  score: number | null
  opponent_score: number | null
  // ノーゲーム（試合が成立しなかった）。投手の休養は KO・ノーゲームの表を使う
  no_game?: boolean
  starting_lineup: LineupItem[] | null
}
