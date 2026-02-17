export interface Cost {
  id: number;
  name: string;
  start_date: string;
  end_date: string;
  normal_cost: number | null;
  relief_only_cost: number | null;
  pitcher_only_cost: number | null;
  fielder_only_cost: number | null;
  two_way_cost: number | null;
}