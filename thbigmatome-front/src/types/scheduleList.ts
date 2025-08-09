export interface ScheduleList {
  id: number | null | undefined;
  name: string;
  start_date: Date | null;
  end_date: Date | null;
  effective_date: Date | null;
}
