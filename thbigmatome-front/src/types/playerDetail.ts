export interface PlayerDetail {
  id: number | null
  name: string
  number: string | null
  short_name: string | null
  handedness: string | null
  is_pitcher: boolean
  is_relief_only: boolean
  pitching_style_description: string | null
  special_throwing_c: number | null
}
