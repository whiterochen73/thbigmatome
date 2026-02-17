export interface CostPlayer {
  id: number;
  number: string | null;
  name: string;
  player_types: { id: number; name: string }[];
  normal_cost: number | null
  relief_only_cost: number | null
  pitcher_only_cost: number | null
  fielder_only_cost: number | null
  two_way_cost: number | null
  [key: string]: any;
}
