export interface PlayerType {
  id: number
  name: string
  description: string | null
  category: 'touhou' | 'outside_world' | 'cost_regulation' | null
}
