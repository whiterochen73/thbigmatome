export interface PlayerCost {
  id: number;
  cost_id: number;
  player_id: number;
  normal_cost: number | null;
  relief_only_cost: number | null;
  pitcher_only_cost: number | null;
  fielder_only_cost: number | null;
  two_way_cost: number | null;
}
