import type { SeasonSchedule } from './seasonSchedule';

export interface SeasonDetail {
  id: number;
  name: string;
  current_date: string;
  start_date: string;
  end_date: string;
  season_schedules: SeasonSchedule[];
}
