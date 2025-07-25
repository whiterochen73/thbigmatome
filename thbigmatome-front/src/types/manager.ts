import { type Team } from './team';

export interface Manager {
  id: number;
  name: string;
  short_name?: string | null;
  irc_name?: string | null;
  user_id?: string | null;
  teams?: Team[];
}