// Shared TypeScript types for game record related components
// Consolidates types previously duplicated across AtBatCard.vue, GameRecordDetailView.vue, PlayerCardItem.vue

export interface SourceEvent {
  seq?: number
  type: 'declaration' | 'dice' | 'auto' | 'skip'
  dice_type?: string
  action?: string
  text?: string
  roll?: number | number[]
  result?: string
  reason?: string
  from?: string
  to?: string
  [key: string]: unknown
}

export interface Discrepancy {
  field: string
  text_value: unknown
  gsm_value: unknown
  cause: 'parser_misread' | 'human_error' | 'gsm_limitation' | 'ambiguous' | 'unknown'
  resolution: 'gsm' | 'text' | 'manual' | null
  resolution_value?: unknown
  note?: string
}

export interface AtBatRecord {
  id: number
  game_record_id: number
  inning: number
  half: 'top' | 'bottom'
  ab_num: number
  batter_name: string
  pitcher_name: string
  result_code: string | null
  runs_scored: number | null
  runners_before: unknown
  runners_after: unknown
  outs_before: number | null
  outs_after: number | null
  strategy: string | null
  play_description: string | null
  is_modified: boolean
  is_reviewed: boolean
  review_notes: string | null
  modified_fields: unknown
  discrepancies: Discrepancy[]
  source_events: SourceEvent[] | null
}

export interface Defense {
  id?: number
  position: string
  range_value?: number
  error_rank?: string
  throwing?: string | null
}

export interface PlayerCard {
  id: number
  card_set_id: number
  player_id: number
  card_type: 'pitcher' | 'batter'
  player_name: string
  player_number: string
  card_set_name: string
  speed: number
  steal_start: number
  steal_end: number
  injury_rate: number
  card_image_path: string | null
  cost?: number | null
  defenses?: Defense[]
  unique_traits?: string | null
}
