<template>
  <v-container>
    <v-toolbar
      color="orange-lighten-3"
    >
      <template #prepend>
        <h1 class="text-h4 mx-4">{{ season?.name }}</h1>
      </template>
      <v-btn
        class="mx-2"
        color="primary"
        variant="flat"
        :to="gameResultRoute"
        :disabled="!isGameDayToday"
      >
        {{ t('seasonPortal.goToGameResult') }}
      </v-btn>
      <v-btn
        class="mx-2"
        color="secondary"
        variant="flat"
        :to="playerRegistrationRoute"
      >
        {{ t('activeRoster.title') }}
      </v-btn>
      <template #append>
        <v-btn
          icon
          variant="text"
          @click="prevDay"
          :disabled="isPrevDayDisabled"
        >
          <v-icon>mdi-chevron-left</v-icon>
        </v-btn>
        <p class="text-h5">{{ t('seasonPortal.currentDate') }}: {{ currentDateStr }}</p>
        <v-btn
          icon
          variant="text"
          @click="nextDay"
          :disabled="isNextDayDisabled"
        >
          <v-icon>mdi-chevron-right</v-icon>
        </v-btn>
      </template>
    </v-toolbar>

    <v-row class="mt-4">
      <v-col>
        <div class="d-flex justify-space-between align-center mb-4">
          <v-btn icon @click="prevMonth">
            <v-icon>mdi-chevron-left</v-icon>
          </v-btn>
          <h2 class="text-h5">{{ monthStr }}</h2>
          <v-btn icon @click="nextMonth">
            <v-icon>mdi-chevron-right</v-icon>
          </v-btn>
        </div>

        <div class="calendar-grid">
          <div v-for="day in weekdays" :key="day" class="text-center font-weight-bold">
            {{ day }}
          </div>
          <div v-for="day in calendarDays" :key="day.date.toISOString()"
                :class="['day-cell', {
                  'is-current-day': day.isCurrentDay,
                  'not-current-month': !day.isCurrentMonth,
                  'saturday': day.dayOfWeek === 6 && day.isCurrentMonth,
                  'sunday': day.dayOfWeek === 0 && day.isCurrentMonth
                }]">
            <div class="day-number">{{ day.date.getDate() }}</div>
            <div v-if="day.schedule">
              <v-menu>
                <template #activator="{ props }">
                  <v-btn
                    :color="getScheduleColor(day.schedule.date_type)"
                    v-bind="props"
                    :disabled="isDateBeforeCurrent(day.date)"
                    block
                    density="compact"
                  >
                    {{ t(`settings.schedule.dateTypes.${day.schedule.date_type}`) }}
                  </v-btn>
                </template>
                <v-list>
                  <v-list-item
                    v-for="dateType in dateTypes"
                    :key="dateType"
                    @click="updateSchedule(day.schedule, dateType)"
                  >
                    <v-list-item-title>{{ t(`settings.schedule.dateTypes.${dateType}`) }}</v-list-item-title>
                  </v-list-item>
                </v-list>
              </v-menu>
              <v-btn
                color="primary"
                block
                density="compact"
                v-if="['game_day', 'interleague_game_day', 'playoff_day', 'no_game'].includes(day.schedule.date_type)"
                :to="{ name: 'GameResult', params: { teamId: teamId, scheduleId: day.schedule.id } }"
              >
                {{ t('seasonPortal.gameResultInput') }}
              </v-btn>
              <div
                v-if="['game_day', 'interleague_game_day', 'playoff_day'].includes(day.schedule.date_type) && day.schedule.game_result"
                class="text-center text-caption mt-1"
              >
                vs. {{ day.schedule.game_result.opponent_short_name }} {{ day.schedule.game_result.score }}
                <v-chip
                  :color="getResultColor(day.schedule.game_result.result)"
                  size="x-small"
                  class="ml-1"
                  variant="elevated"
                >
                  <v-icon start :icon="getResultIcon(day.schedule.game_result.result)"></v-icon>
                  {{ t(`seasonPortal.gameResult.${day.schedule.game_result.result}`) }}
                </v-chip>
              </div>
              <div
                v-else-if="['game_day', 'interleague_game_day', 'playoff_day'].includes(day.schedule.date_type) && day.schedule.announced_starter"
                class="text-center text-caption mt-1"
              >
                {{ t('seasonPortal.announcedPitcher') }}: {{ day.schedule.announced_starter.name }}
              </div>
            </div>
          </div>
        </div>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRoute } from 'vue-router';
import axios from 'axios';
import { useI18n } from 'vue-i18n';
import type { SeasonDetail } from '@/types/seasonDetail';
import type { SeasonSchedule } from '@/types/seasonSchedule';

const { t } = useI18n();
const route = useRoute();
const season = ref<SeasonDetail | null>(null);
const currentDate = ref(new Date());

const teamId = route.params.teamId;

const fetchSeason = async () => {
  try {
    const response = await axios.get(`/teams/${teamId}/season`);
    season.value = response.data;
    if (season.value) {
      currentDate.value = new Date(season.value.current_date);
    }
  } catch (error) {
    console.error('Failed to fetch season data:', error);
  }
};

const updateSeasonCurrentDate = async (date: Date) => {
  try {
    if (!season.value) return;
    const formattedDate = date.toISOString().split('T')[0]; // YYYY-MM-DD
    await axios.patch(`/teams/${teamId}/season`, { season: { current_date: formattedDate } });
    await fetchSeason();
  } catch (error) {
    console.error('Failed to update season current date:', error);
  }
};

const currentDateStr = computed(() => {
  return currentDate.value.toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' });
});

const monthStr = computed(() => {
  return currentDate.value.toLocaleDateString('ja-JP', { month: 'long' });
});

const isPrevDayDisabled = computed(() => {
  if (!season.value || !season.value.start_date) return true;
  const start = new Date(season.value.start_date);
  const current = new Date(currentDate.value);
  return current <= start;
});

const isNextDayDisabled = computed(() => {
  if (!season.value || !season.value.end_date) return true;
  const end = new Date(season.value.end_date);
  const current = new Date(currentDate.value);
  return current >= end;
});

const prevDay = () => {
  const newDate = new Date(currentDate.value);
  newDate.setDate(newDate.getDate() - 1);
  currentDate.value = newDate;
  updateSeasonCurrentDate(newDate);
};

const nextDay = () => {
  const newDate = new Date(currentDate.value);
  newDate.setDate(newDate.getDate() + 1);
  currentDate.value = newDate;
  updateSeasonCurrentDate(newDate);
};

const weekdays = computed(() => {
  const format = new Intl.DateTimeFormat('ja-JP', { weekday: 'short' });
  // Start from Monday (2021-06-07 was a Monday)
  return [...Array(7).keys()].map(day => {
      const date = new Date(Date.UTC(2021, 5, 7)); // A Monday
      date.setDate(date.getDate() + day);
      return format.format(date);
  });
});

const calendarDays = computed(() => {
  if (!season.value) return [];

  const year = currentDate.value.getFullYear();
  const month = currentDate.value.getMonth();
  const startDate = new Date(year, month, 1);
  const endDate = new Date(year, month + 1, 0);

  const days = [];
  // Adjust startDayOfWeek for Monday start
  const startDayOfWeek = (startDate.getDay() + 6) % 7; // 0 for Monday, 6 for Sunday

  for (let i = startDayOfWeek; i > 0; i--) {
    const date = new Date(startDate);
    date.setDate(date.getDate() - i);
    days.push({ date, isCurrentMonth: false, isCurrentDay: false, isWeekend: false, dayOfWeek: date.getDay(), schedule: null });
  }

  for (let i = 1; i <= endDate.getDate(); i++) {
    const date = new Date(year, month, i);
    const isCurrentDay = date.getFullYear() === currentDate.value.getFullYear() &&
                    date.getMonth() === currentDate.value.getMonth() &&
                    date.getDate() === currentDate.value.getDate();
    const dayOfWeek = date.getDay(); // 0 for Sunday, 6 for Saturday
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6; // Sunday or Saturday

    const schedule = season.value.season_schedules.find(s => {
      const scheduleDate = new Date(s.date);
      return scheduleDate.getFullYear() === date.getFullYear() &&
             scheduleDate.getMonth() === date.getMonth() &&
             scheduleDate.getDate() === date.getDate();
    });
    days.push({ date, isCurrentMonth: true, isCurrentDay, isWeekend, dayOfWeek, schedule });
  }

  const endDayOfWeek = (endDate.getDay() + 6) % 7; // 0 for Monday, 6 for Sunday
  for (let i = 1; i < 7 - endDayOfWeek; i++) {
    const date = new Date(endDate);
    date.setDate(date.getDate() + i);
    days.push({ date, isCurrentMonth: false, isCurrentDay: false, isWeekend: false, dayOfWeek: date.getDay(), schedule: null });
  }

  return days;
});

const prevMonth = () => {
  currentDate.value = new Date(currentDate.value.setMonth(currentDate.value.getMonth() - 1));
};

const nextMonth = () => {
  currentDate.value = new Date(currentDate.value.setMonth(currentDate.value.getMonth() + 1));
};

const dateTypes = [
  'game_day',
  'interleague_game_day',
  'playoff_day',
  'travel_day',
  'reserve_day',
  'interleague_reserve_day',
  'no_game_day',
  'postponed',
  'no_game',
];

const getScheduleColor = (dateType: string) => {
  const colors: { [key: string]: string } = {
    game_day: 'blue',
    interleague_game_day: 'deep-purple',
    playoff_day: 'pink',
    travel_day: 'grey',
    reserve_day: 'blue-grey',
    interleague_reserve_day: 'brown',
    no_game_day: 'red',
    postponed: 'indigo',
    no_game: 'indigo',
  };
  return colors[dateType] || '#FFFFFF';
};

const isDateBeforeCurrent = (date: Date) => {
  if (!season.value || !season.value.current_date) return false;
  const current = new Date(season.value.current_date);
  // Set hours, minutes, seconds, milliseconds to 0 for accurate date comparison
  date.setHours(0, 0, 0, 0);
  current.setHours(0, 0, 0, 0);
  return date < current;
};

const updateSchedule = async (schedule: SeasonSchedule, newDateType: string) => {
  try {
    await axios.patch(`/teams/${teamId}/season/season_schedules/${schedule.id}`, { season_schedule: { date_type: newDateType } });
    // Update the local schedule object to reflect the change
    if (season.value) {
      const index = season.value.season_schedules.findIndex(s => s.id === schedule.id);
      if (index !== -1) {
        season.value.season_schedules[index].date_type = newDateType;
      }
    }
  } catch (error) {
    console.error('Failed to update schedule:', error);
  }
};

const playerRegistrationRoute = computed(() => {
  return `/teams/${teamId}/roster`;
});

const currentDaySchedule = computed(() => {
  if (!season.value) return null;
  const current = new Date(currentDate.value);
  current.setHours(0, 0, 0, 0);

  return season.value.season_schedules.find(s => {
    const scheduleDate = new Date(s.date);
    scheduleDate.setHours(0, 0, 0, 0);
    return scheduleDate.getTime() === current.getTime();
  });
});

const isGameDayToday = computed(() => {
  if (!currentDaySchedule.value) return false;
  const gameDayTypes = ['game_day', 'interleague_game_day', 'playoff_day', 'no_game'];
  return gameDayTypes.includes(currentDaySchedule.value.date_type);
});

const gameResultRoute = computed(() => {
  if (!isGameDayToday.value || !currentDaySchedule.value) return '';
  return {
    name: 'GameResult',
    params: {
      teamId: teamId,
      scheduleId: currentDaySchedule.value.id
    }
  };
});

const getResultColor = (result: string) => {
  switch (result) {
    case 'win':
      return 'success';
    case 'lose':
      return 'error';
    case 'draw':
      return 'grey-darken-1';
    default:
      return 'default';
  }
};

const getResultIcon = (result: string) => {
  switch (result) {
    case 'win':
      return 'mdi-circle';
    case 'lose':
      return 'mdi-close';
    case 'draw':
      return 'mdi-triangle';
    default:
      return '';
  }
};

onMounted(fetchSeason);
</script>

<style scoped>
.calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 4px;
}

.day-cell {
  border: 1px solid #ccc;
  padding: 8px;
  min-height: 100px;
  position: relative;
}

.day-number {
  font-size: 0.8em;
  color: #555;
}

.not-current-month {
  background-color: #f9f9f9;
  color: #aaa;
}

.schedule-type {
  font-size: 0.7em;
  padding: 2px 4px;
  border-radius: 4px;
  margin-top: 4px;
  text-align: center;
}

.saturday {
  background-color: #e0f2f7; /* Light blue */
}

.sunday {
  background-color: #ffebee; /* Light red */
}

.is-current-day {
  background-color: #FFFDE7;
  border: 2px solid #FFEB3B; /* Blue border for current-day */
}
</style>
