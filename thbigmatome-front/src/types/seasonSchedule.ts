export interface SeasonSchedule {
  id: number;
  date: string;
  date_type: string;
  announced_starter?: { id: number; name: string };
  game_result?: {
    opponent_short_name: string;
    score: string;
    result: 'win' | 'lose' | 'draw';
  };
}
