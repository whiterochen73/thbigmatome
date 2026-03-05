<template>
  <v-container>
    <TeamNavigation :team-id="teamId" />
    <v-toolbar color="primary">
      <template #prepend>
        <h1 class="text-h5 mx-4">{{ season?.name }}</h1>
      </template>
      <v-btn class="mx-2" variant="outlined" :to="gameResultRoute" :disabled="!isGameDayToday">
        {{ t('seasonPortal.goToGameResult') }}
      </v-btn>
      <v-btn
        class="mx-2"
        color="secondary"
        variant="outlined"
        prepend-icon="mdi-hospital-box"
        @click="isDialogOpen = true"
      >
        {{ t('seasonPortal.registerAbsence') }}
      </v-btn>
      <v-btn
        class="mx-2"
        color="secondary"
        variant="outlined"
        prepend-icon="mdi-chart-bar"
        :to="{ name: '成績集計' }"
      >
        {{ t('seasonPortal.goToStats') }}
      </v-btn>
      <template #append>
        <v-btn icon variant="text" @click="prevDay" :disabled="isPrevDayDisabled">
          <v-icon>mdi-chevron-left</v-icon>
        </v-btn>
        <p class="text-h5">{{ t('seasonPortal.currentDate') }}: {{ currentDateStr }}</p>
        <v-btn icon variant="text" @click="nextDay" :disabled="isNextDayDisabled">
          <v-icon>mdi-chevron-right</v-icon>
        </v-btn>
      </template>
    </v-toolbar>

    <EmptyState
      v-if="!season"
      icon="mdi-calendar-blank-outline"
      message="シーズンデータが見つかりません"
    />

    <v-tabs v-if="season" v-model="activeTab" color="primary" class="mt-2">
      <v-tab value="calendar">
        <v-icon start>mdi-calendar</v-icon>
        {{ t('seasonPortal.tabs.calendar') }}
      </v-tab>
      <v-tab value="roster">
        <v-icon start>mdi-account-group</v-icon>
        {{ t('seasonPortal.tabs.roster') }}
      </v-tab>
      <v-tab value="absences">
        <v-icon start>mdi-account-off</v-icon>
        {{ t('seasonPortal.tabs.absences') }}
      </v-tab>
    </v-tabs>

    <v-tabs-window v-if="season" v-model="activeTab">
      <!-- タブ1: カレンダー -->
      <v-tabs-window-item value="calendar">
        <v-row class="mt-2">
          <v-col>
            <AbsenceInfo
              :season-id="season?.id || null"
              :current-date="formattedCurrentDate"
              ref="absenceInfo"
              class="mb-4"
            />

            <v-card variant="outlined" class="pa-4">
              <div class="d-flex justify-space-between align-center mb-4">
                <v-btn icon variant="outlined" @click="prevMonth">
                  <v-icon>mdi-chevron-left</v-icon>
                </v-btn>
                <h2 class="text-h5">{{ monthStr }}</h2>
                <v-btn icon variant="outlined" @click="nextMonth">
                  <v-icon>mdi-chevron-right</v-icon>
                </v-btn>
              </div>

              <div class="calendar-grid">
                <div
                  v-for="day in weekdays"
                  :key="day"
                  class="weekday-header text-center font-weight-bold"
                >
                  {{ day }}
                </div>
                <div
                  v-for="day in calendarDays"
                  :key="day.date.toISOString()"
                  :class="[
                    'day-cell',
                    {
                      'is-current-day': day.isCurrentDay,
                      'not-current-month': !day.isCurrentMonth,
                      saturday: day.dayOfWeek === 6 && day.isCurrentMonth,
                      sunday: day.dayOfWeek === 0 && day.isCurrentMonth,
                    },
                  ]"
                >
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
                          <v-list-item-title>{{
                            t(`settings.schedule.dateTypes.${dateType}`)
                          }}</v-list-item-title>
                        </v-list-item>
                      </v-list>
                    </v-menu>
                    <v-btn
                      color="primary"
                      block
                      density="compact"
                      v-if="
                        ['game_day', 'interleague_game_day', 'playoff_day', 'no_game'].includes(
                          day.schedule.date_type,
                        )
                      "
                      :to="{
                        name: 'GameResult',
                        params: { teamId: teamId, scheduleId: day.schedule.id },
                      }"
                    >
                      {{ t('seasonPortal.gameResultInput') }}
                    </v-btn>
                    <div
                      v-if="
                        ['game_day', 'interleague_game_day', 'playoff_day'].includes(
                          day.schedule.date_type,
                        ) && day.schedule.game_result
                      "
                      class="text-center text-caption mt-1"
                    >
                      vs. {{ day.schedule.game_result.opponent_short_name }}
                      {{ day.schedule.game_result.score }}
                      <v-chip
                        :color="getResultColor(day.schedule.game_result.result)"
                        size="x-small"
                        class="ml-1"
                        variant="elevated"
                      >
                        <v-icon
                          start
                          :icon="getResultIcon(day.schedule.game_result.result)"
                        ></v-icon>
                        {{ t(`seasonPortal.gameResult.${day.schedule.game_result.result}`) }}
                      </v-chip>
                    </div>
                    <div
                      v-else-if="
                        ['game_day', 'interleague_game_day', 'playoff_day'].includes(
                          day.schedule.date_type,
                        ) && day.schedule.announced_starter
                      "
                      class="text-center text-caption mt-1"
                    >
                      {{ t('seasonPortal.announcedPitcher') }}:
                      {{ day.schedule.announced_starter.name }}
                    </div>
                  </div>
                </div>
              </div>

              <!-- 凡例 -->
              <div class="calendar-legend mt-3">
                <v-chip
                  v-for="item in legendItems"
                  :key="item.type"
                  :color="item.color"
                  size="x-small"
                  variant="tonal"
                  class="mr-1 mb-1"
                >
                  {{ t(`settings.schedule.dateTypes.${item.type}`) }}
                </v-chip>
              </div>
            </v-card>
          </v-col>
        </v-row>
      </v-tabs-window-item>

      <!-- タブ2: ロスター -->
      <v-tabs-window-item value="roster">
        <div class="mt-2">
          <SeasonRosterTab :team-id="teamId" />
        </div>
      </v-tabs-window-item>

      <!-- タブ3: 離脱者 -->
      <v-tabs-window-item value="absences">
        <div class="mt-2">
          <SeasonAbsenceTab :team-id="teamId" />
        </div>
      </v-tabs-window-item>
    </v-tabs-window>
  </v-container>

  <PlayerAbsenceFormDialog
    v-model="isDialogOpen"
    :team-id="teamId || 0"
    :season-id="season?.id || 0"
    :initial-start-date="formattedCurrentDate"
    @saved="handleAbsenceSaved"
  />
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch, useTemplateRef } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import type { SeasonDetail } from '@/types/seasonDetail'
import type { SeasonSchedule } from '@/types/seasonSchedule'
import type { Team } from '@/types/team'
import AbsenceInfo from '@/components/AbsenceInfo.vue'
import PlayerAbsenceFormDialog from '@/components/PlayerAbsenceFormDialog.vue'
import TeamNavigation from '@/components/TeamNavigation.vue'
import SeasonRosterTab from '@/components/season/SeasonRosterTab.vue'
import SeasonAbsenceTab from '@/components/season/SeasonAbsenceTab.vue'
import EmptyState from '@/components/EmptyState.vue'
import { useTeamSelectionStore } from '@/stores/teamSelection'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const teamSelectionStore = useTeamSelectionStore()
const season = ref<SeasonDetail | null>(null)
const currentDate = ref(new Date())
const formattedCurrentDate = computed(() => currentDate.value.toISOString().split('T')[0])
const absenceInfo = useTemplateRef('absenceInfo')
const isDialogOpen = ref(false)

const teamId = parseInt(<string>route.params.teamId, 10)

// タブ状態をURLクエリパラメータで管理
const activeTab = ref((route.query.tab as string) || 'calendar')

watch(activeTab, (newTab) => {
  router.replace({ query: { ...route.query, tab: newTab } })
})

watch(
  () => route.query.tab,
  (newTab) => {
    if (newTab && newTab !== activeTab.value) {
      activeTab.value = newTab as string
    }
  },
)

const fetchSeason = async () => {
  try {
    const response = await axios.get(`/teams/${teamId}/season`)
    season.value = response.data
    if (season.value) {
      currentDate.value = new Date(season.value.current_date)
    }
  } catch (error) {
    console.error('Failed to fetch season data:', error)
  }
}

const updateSeasonCurrentDate = async (date: Date) => {
  try {
    if (!season.value) return
    const formattedDate = date.toISOString().split('T')[0]
    await axios.patch(`/teams/${teamId}/season`, { season: { current_date: formattedDate } })
    await fetchSeason()
  } catch (error) {
    console.error('Failed to update season current date:', error)
  }
}

const handleAbsenceSaved = () => {
  absenceInfo.value?.fetchPlayerAbsences()
}

const currentDateStr = computed(() => {
  return currentDate.value.toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' })
})

const monthStr = computed(() => {
  return currentDate.value.toLocaleDateString('ja-JP', { month: 'long' })
})

const isPrevDayDisabled = computed(() => {
  if (!season.value || !season.value.start_date) return true
  const start = new Date(season.value.start_date)
  const current = new Date(currentDate.value)
  return current <= start
})

const isNextDayDisabled = computed(() => {
  if (!season.value || !season.value.end_date) return true
  const end = new Date(season.value.end_date)
  const current = new Date(currentDate.value)
  return current >= end
})

const prevDay = () => {
  const newDate = new Date(currentDate.value)
  newDate.setDate(newDate.getDate() - 1)
  currentDate.value = newDate
  updateSeasonCurrentDate(newDate)
}

const nextDay = () => {
  const newDate = new Date(currentDate.value)
  newDate.setDate(newDate.getDate() + 1)
  currentDate.value = newDate
  updateSeasonCurrentDate(newDate)
}

const weekdays = computed(() => {
  const format = new Intl.DateTimeFormat('ja-JP', { weekday: 'short' })
  return [...Array(7).keys()].map((day) => {
    const date = new Date(Date.UTC(2021, 5, 7))
    date.setDate(date.getDate() + day)
    return format.format(date)
  })
})

const calendarDays = computed(() => {
  if (!season.value) return []

  const year = currentDate.value.getFullYear()
  const month = currentDate.value.getMonth()
  const startDate = new Date(year, month, 1)
  const endDate = new Date(year, month + 1, 0)

  const days = []
  const startDayOfWeek = (startDate.getDay() + 6) % 7

  for (let i = startDayOfWeek; i > 0; i--) {
    const date = new Date(startDate)
    date.setDate(date.getDate() - i)
    days.push({
      date,
      isCurrentMonth: false,
      isCurrentDay: false,
      isWeekend: false,
      dayOfWeek: date.getDay(),
      schedule: null,
    })
  }

  for (let i = 1; i <= endDate.getDate(); i++) {
    const date = new Date(year, month, i)
    const isCurrentDay =
      date.getFullYear() === currentDate.value.getFullYear() &&
      date.getMonth() === currentDate.value.getMonth() &&
      date.getDate() === currentDate.value.getDate()
    const dayOfWeek = date.getDay()
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6

    const schedule = season.value.season_schedules.find((s) => {
      const scheduleDate = new Date(s.date)
      return (
        scheduleDate.getFullYear() === date.getFullYear() &&
        scheduleDate.getMonth() === date.getMonth() &&
        scheduleDate.getDate() === date.getDate()
      )
    })
    days.push({ date, isCurrentMonth: true, isCurrentDay, isWeekend, dayOfWeek, schedule })
  }

  const endDayOfWeek = (endDate.getDay() + 6) % 7
  for (let i = 1; i < 7 - endDayOfWeek; i++) {
    const date = new Date(endDate)
    date.setDate(date.getDate() + i)
    days.push({
      date,
      isCurrentMonth: false,
      isCurrentDay: false,
      isWeekend: false,
      dayOfWeek: date.getDay(),
      schedule: null,
    })
  }

  return days
})

const prevMonth = () => {
  currentDate.value = new Date(currentDate.value.setMonth(currentDate.value.getMonth() - 1))
}

const nextMonth = () => {
  currentDate.value = new Date(currentDate.value.setMonth(currentDate.value.getMonth() + 1))
}

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
]

const legendItems = [
  { type: 'game_day', color: 'primary' },
  { type: 'interleague_game_day', color: 'info' },
  { type: 'playoff_day', color: 'warning' },
  { type: 'no_game_day', color: 'error' },
  { type: 'postponed', color: 'accent' },
  { type: 'travel_day', color: 'secondary' },
  { type: 'reserve_day', color: 'secondary' },
  { type: 'no_game', color: 'success' },
]

const getScheduleColor = (dateType: string) => {
  const colors: { [key: string]: string } = {
    game_day: 'primary', // 藍色 — メインイベント
    interleague_game_day: 'info', // 浅葱 — 交流戦
    playoff_day: 'warning', // 山吹 — 特別
    travel_day: 'secondary', // 千草 — 移動
    reserve_day: 'secondary', // 千草 — 予備
    interleague_reserve_day: 'secondary',
    no_game_day: 'error', // 紅 — 試合なし
    postponed: 'accent', // 朱色 — 延期
    no_game: 'success', // 萌黄 — 休養
  }
  return colors[dateType] || 'surface-variant'
}

const isDateBeforeCurrent = (date: Date) => {
  if (!season.value || !season.value.current_date) return false
  const current = new Date(season.value.current_date)
  date.setHours(0, 0, 0, 0)
  current.setHours(0, 0, 0, 0)
  return date < current
}

const updateSchedule = async (schedule: SeasonSchedule, newDateType: string) => {
  try {
    await axios.patch(`/teams/${teamId}/season/season_schedules/${schedule.id}`, {
      season_schedule: { date_type: newDateType },
    })
    if (season.value) {
      const index = season.value.season_schedules.findIndex((s) => s.id === schedule.id)
      if (index !== -1) {
        season.value.season_schedules[index].date_type = newDateType
      }
    }
  } catch (error) {
    console.error('Failed to update schedule:', error)
  }
}

const currentDaySchedule = computed(() => {
  if (!season.value) return null
  const current = new Date(currentDate.value)
  current.setHours(0, 0, 0, 0)

  return season.value.season_schedules.find((s) => {
    const scheduleDate = new Date(s.date)
    scheduleDate.setHours(0, 0, 0, 0)
    return scheduleDate.getTime() === current.getTime()
  })
})

const isGameDayToday = computed(() => {
  if (!currentDaySchedule.value) return false
  const gameDayTypes = ['game_day', 'interleague_game_day', 'playoff_day', 'no_game']
  return gameDayTypes.includes(currentDaySchedule.value.date_type)
})

const gameResultRoute = computed(() => {
  if (!isGameDayToday.value || !currentDaySchedule.value) return ''
  return {
    name: 'GameResult',
    params: {
      teamId: teamId,
      scheduleId: currentDaySchedule.value.id,
    },
  }
})

const getResultColor = (result: string) => {
  switch (result) {
    case 'win':
      return 'success'
    case 'lose':
      return 'error'
    case 'draw':
      return 'grey-darken-1'
    default:
      return 'default'
  }
}

const getResultIcon = (result: string) => {
  switch (result) {
    case 'win':
      return 'mdi-circle'
    case 'lose':
      return 'mdi-close'
    case 'draw':
      return 'mdi-triangle'
    default:
      return ''
  }
}

onMounted(async () => {
  await fetchSeason()
  try {
    const response = await axios.get<Team>(`/teams/${teamId}`)
    teamSelectionStore.selectTeam(teamId, response.data.name)
  } catch {
    teamSelectionStore.selectTeam(teamId, '')
  }
})
</script>

<style scoped>
.calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 4px;
}

.weekday-header {
  background-color: rgb(var(--v-theme-surface-variant));
  color: rgb(var(--v-theme-on-surface-variant));
  padding: 4px 0;
  border-radius: 4px;
  font-size: 0.85em;
}

.day-cell {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  padding: 8px;
  min-height: 100px;
  position: relative;
}

.day-number {
  font-size: 0.8em;
  color: rgb(var(--v-theme-text-medium));
}

.not-current-month {
  background-color: rgb(var(--v-theme-surface-variant));
  color: rgb(var(--v-theme-text-caption));
}

.schedule-type {
  font-size: 0.7em;
  padding: 2px 4px;
  border-radius: 4px;
  margin-top: 4px;
  text-align: center;
}

.saturday {
  background-color: rgba(var(--v-theme-info), 0.1);
}

.sunday {
  background-color: rgba(var(--v-theme-error), 0.1);
}

.is-current-day {
  background-color: rgba(var(--v-theme-primary), 0.12);
  border: 2px solid rgb(var(--v-theme-primary));
}

.calendar-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 2px;
}

/* タブレット: セル内テキスト省略 */
@media (max-width: 960px) {
  .day-cell {
    padding: 4px;
    min-height: 80px;
  }
}

/* モバイル: 4列グリッドに縮小 */
@media (max-width: 600px) {
  .calendar-grid {
    grid-template-columns: repeat(4, 1fr);
    font-size: 0.75em;
  }

  .weekday-header:nth-child(n + 5) {
    display: none;
  }

  .day-cell {
    min-height: 60px;
    padding: 3px;
  }

  .day-number {
    font-size: 0.75em;
  }
}
</style>
