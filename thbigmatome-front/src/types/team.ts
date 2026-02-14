import { type Manager } from '@/types/manager'

export interface Team {
  id: number;
  name: string;
  short_name: string;
  is_active: boolean;
  has_season: boolean;
  director?: Manager;
  coaches?: Manager[];
}
