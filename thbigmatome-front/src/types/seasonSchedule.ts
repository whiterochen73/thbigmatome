export interface SeasonSchedule {
  id: number;
  date: string;
  date_type: string;
  announced_starter?: { id: number; name: string };
  game_result?: {
    opponent_short_name: string;
    // ノーゲームは得点を出さない（null）。勝敗の印にしない（台帳 D-11）
    score: string | null;
    result: 'win' | 'lose' | 'draw' | 'no_game';
  };
}
