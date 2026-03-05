<template>
  <v-container>
    <v-toolbar color="primary">
      <template #prepend>
        <h1 class="text-h5 mx-4">{{ season?.name }}</h1>
      </template>
      <v-btn class="mx-2" variant="outlined" :to="gameResultRoute" :disabled="!isGameDayToday">
        {{ t('seasonPortal.goToGameResult') }}
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
      <v-tab value="members">
        <v-icon start>mdi-account-cog</v-icon>
        {{ t('seasonPortal.tabs.members') }}
      </v-tab>
      <v-tab value="stats">
        <v-icon start>mdi-chart-bar</v-icon>
        {{ t('seasonPortal.tabs.stats') }}
      </v-tab>
    </v-tabs>

    <v-tabs-window v-if="season" v-model="activeTab">
      <!-- タブ1: カレンダー -->
      <v-tabs-window-item value="calendar">
        <v-row class="mt-2">
          <v-col>
            <v-card variant="outlined" class="pa-4">
              <!-- ツールバー: 月ナビ + ビュー切替 -->
              <div class="cal-toolbar mb-4">
                <div class="month-nav">
                  <v-btn icon variant="outlined" size="small" @click="prevMonth">
                    <v-icon>mdi-chevron-left</v-icon>
                  </v-btn>
                  <h2 class="month-label">{{ monthStr }}</h2>
                  <v-btn icon variant="outlined" size="small" @click="nextMonth">
                    <v-icon>mdi-chevron-right</v-icon>
                  </v-btn>
                </div>
                <v-btn-toggle
                  v-model="viewMode"
                  mandatory
                  density="compact"
                  variant="outlined"
                  color="primary"
                >
                  <v-btn value="calendar" title="カレンダー表示">
                    <v-icon>mdi-calendar-month</v-icon>
                  </v-btn>
                  <v-btn value="table" title="リスト表示">
                    <v-icon>mdi-format-list-bulleted</v-icon>
                  </v-btn>
                </v-btn-toggle>
              </div>

              <!-- カレンダーグリッドビュー -->
              <template v-if="viewMode === 'calendar'">
                <div class="cal-wrapper">
                  <div class="calendar-grid">
                    <!-- 曜日ヘッダー -->
                    <div
                      v-for="(day, i) in weekdays"
                      :key="day"
                      class="weekday-header text-center font-weight-bold"
                      :class="{ 'sat-header': i === 5, 'sun-header': i === 6 }"
                    >
                      {{ day }}
                    </div>
                    <!-- 日付セル -->
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
                      @click="openDayDetail(day)"
                    >
                      <div class="day-num-wrapper">
                        <span
                          class="day-number"
                          :class="{
                            'today-circle': day.isCurrentDay,
                            'sat-num': day.dayOfWeek === 6 && day.isCurrentMonth,
                            'sun-num': day.dayOfWeek === 0 && day.isCurrentMonth,
                          }"
                        >
                          {{ day.date.getDate() }}
                        </span>
                      </div>

                      <div v-if="day.isCurrentMonth && day.schedule" class="cell-content">
                        <!-- 日程種別チップ (未来日はv-menuで編集可) -->
                        <v-menu v-if="!isDateBeforeCurrent(day.date)">
                          <template #activator="{ props }">
                            <span
                              v-bind="props"
                              class="type-chip"
                              :class="`chip-${getTypeCategory(day.schedule.date_type)}`"
                              @click.stop
                            >
                              {{ t(`settings.schedule.dateTypes.${day.schedule.date_type}`) }}
                            </span>
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
                        <span
                          v-else
                          class="type-chip"
                          :class="`chip-${getTypeCategory(day.schedule.date_type)}`"
                        >
                          {{ t(`settings.schedule.dateTypes.${day.schedule.date_type}`) }}
                        </span>

                        <!-- 試合情報 -->
                        <template v-if="isGameType(day.schedule.date_type)">
                          <div
                            v-if="
                              day.schedule.game_result && !isCancelledType(day.schedule.date_type)
                            "
                            class="game-info"
                          >
                            <span class="opponent-text"
                              >vs {{ day.schedule.game_result.opponent_short_name }}</span
                            >
                            <span
                              :class="`result-mark result-${day.schedule.game_result.result}`"
                              >{{ resultMark(day.schedule.game_result.result) }}</span
                            >
                            <span class="score-text">{{ day.schedule.game_result.score }}</span>
                          </div>
                          <div v-else class="game-info">
                            <span v-if="day.schedule.announced_starter" class="starter-text">
                              先発: {{ day.schedule.announced_starter.name }}
                            </span>
                          </div>
                          <v-btn
                            v-if="!isDateBeforeCurrent(day.date)"
                            size="x-small"
                            color="primary"
                            variant="text"
                            density="compact"
                            :to="{
                              name: 'GameResult',
                              params: { teamId, scheduleId: day.schedule.id },
                            }"
                            @click.stop
                            class="entry-btn"
                          >
                            {{ t('seasonPortal.gameResultInput') }}
                          </v-btn>
                        </template>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- 凡例 -->
                <div class="calendar-legend mt-3">
                  <div class="legend-inner">
                    <span v-for="item in legendItems" :key="item.type" class="legend-item">
                      <span class="legend-dot" :class="`chip-${getTypeCategory(item.type)}`"></span>
                      {{ t(`settings.schedule.dateTypes.${item.type}`) }}
                    </span>
                    <span class="legend-results ml-auto">
                      <span class="result-mark result-win">○</span>勝&nbsp;
                      <span class="result-mark result-lose">●</span>負&nbsp;
                      <span class="result-mark result-draw">△</span>分
                    </span>
                  </div>
                </div>
              </template>

              <!-- 表形式ビュー -->
              <template v-else>
                <div class="d-flex align-center mb-3 flex-wrap" style="gap: 8px">
                  <span class="text-caption text-medium-emphasis">表示：</span>
                  <v-btn-toggle
                    v-model="tableFilter"
                    mandatory
                    density="compact"
                    variant="outlined"
                    size="small"
                  >
                    <v-btn value="all">全日程</v-btn>
                    <v-btn value="game">試合日のみ</v-btn>
                  </v-btn-toggle>
                </div>
                <div class="table-wrapper">
                  <table class="schedule-table">
                    <thead>
                      <tr>
                        <th>日付</th>
                        <th>曜日</th>
                        <th>種別</th>
                        <th>対戦相手</th>
                        <th>先発投手</th>
                        <th>スコア</th>
                        <th>勝敗</th>
                        <th></th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr
                        v-for="row in filteredTableRows"
                        :key="row.date.toISOString()"
                        :class="{ 'today-row': row.isCurrentDay }"
                      >
                        <td data-label="日付" class="date-cell">{{ formatTableDate(row.date) }}</td>
                        <td data-label="曜日" class="dow-cell" :class="getDowClass(row.dayOfWeek)">
                          {{ getDowLabel(row.dayOfWeek) }}
                        </td>
                        <td data-label="種別">
                          <span
                            v-if="row.schedule"
                            class="type-badge"
                            :class="`badge-${getTypeCategory(row.schedule.date_type)}`"
                          >
                            {{ t(`settings.schedule.dateTypes.${row.schedule.date_type}`) }}
                          </span>
                          <span v-else class="text-disabled">—</span>
                        </td>
                        <td data-label="対戦相手">
                          <template
                            v-if="
                              row.schedule?.game_result && !isCancelledType(row.schedule.date_type)
                            "
                          >
                            {{ row.schedule.game_result.opponent_short_name }}
                          </template>
                          <span v-else class="text-disabled">—</span>
                        </td>
                        <td data-label="先発投手">
                          <template
                            v-if="
                              row.schedule &&
                              !row.schedule.game_result &&
                              row.schedule.announced_starter
                            "
                          >
                            {{ row.schedule.announced_starter.name }}
                          </template>
                          <span v-else class="text-disabled">—</span>
                        </td>
                        <td data-label="スコア">
                          {{
                            !isCancelledType(row.schedule?.date_type) &&
                            row.schedule?.game_result?.score
                              ? row.schedule.game_result.score
                              : '—'
                          }}
                        </td>
                        <td data-label="勝敗">
                          <span
                            v-if="
                              row.schedule?.game_result && !isCancelledType(row.schedule.date_type)
                            "
                            class="result-badge"
                            :class="`result-${row.schedule.game_result.result}`"
                          >
                            {{ resultMark(row.schedule.game_result.result) }}
                          </span>
                          <span v-else class="text-disabled">—</span>
                        </td>
                        <td>
                          <v-btn
                            v-if="
                              row.schedule &&
                              isGameType(row.schedule.date_type) &&
                              !isDateBeforeCurrent(row.date)
                            "
                            size="x-small"
                            color="primary"
                            variant="text"
                            :to="{
                              name: 'GameResult',
                              params: { teamId, scheduleId: row.schedule.id },
                            }"
                          >
                            入力
                          </v-btn>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </template>
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

      <!-- タブ4: チーム編成 -->
      <v-tabs-window-item value="members">
        <div class="mt-2">
          <TeamMembers />
        </div>
      </v-tabs-window-item>
    </v-tabs-window>
  </v-container>

  <!-- 日程詳細ダイアログ (モバイル用タップ詳細) -->
  <v-dialog v-model="isDayDetailOpen" max-width="400">
    <v-card v-if="selectedDay">
      <v-card-title class="d-flex align-center pt-3 pb-1">
        <span>{{ formatDetailDate(selectedDay.date) }}</span>
        <v-spacer />
        <v-btn icon size="small" variant="text" @click="isDayDetailOpen = false">
          <v-icon>mdi-close</v-icon>
        </v-btn>
      </v-card-title>
      <v-card-text class="pt-2">
        <div v-if="selectedDay.schedule">
          <div class="mb-3">
            <span class="text-caption text-medium-emphasis">種別&ensp;</span>
            <span
              class="type-badge"
              :class="`badge-${getTypeCategory(selectedDay.schedule.date_type)}`"
            >
              {{ t(`settings.schedule.dateTypes.${selectedDay.schedule.date_type}`) }}
            </span>
          </div>
          <template v-if="isGameType(selectedDay.schedule.date_type)">
            <template
              v-if="
                selectedDay.schedule.game_result && !isCancelledType(selectedDay.schedule.date_type)
              "
            >
              <div class="mb-1">
                <span class="text-caption text-medium-emphasis">対戦相手&ensp;</span>
                vs {{ selectedDay.schedule.game_result.opponent_short_name }}
              </div>
              <div class="mb-1">
                <span class="text-caption text-medium-emphasis">スコア&ensp;</span>
                {{ selectedDay.schedule.game_result.score }}
              </div>
              <div class="mb-2">
                <span class="text-caption text-medium-emphasis">結果&ensp;</span>
                <span
                  :class="`result-mark result-${selectedDay.schedule.game_result.result}`"
                  style="font-size: 1.1rem"
                  >{{ resultMark(selectedDay.schedule.game_result.result) }}</span
                >
                {{
                  selectedDay.schedule.game_result.result === 'win'
                    ? '勝ち'
                    : selectedDay.schedule.game_result.result === 'lose'
                      ? '負け'
                      : '引分'
                }}
              </div>
            </template>
            <template v-else>
              <div v-if="selectedDay.schedule.announced_starter" class="mb-2">
                <span class="text-caption text-medium-emphasis">先発投手&ensp;</span>
                {{ selectedDay.schedule.announced_starter.name }}
              </div>
            </template>
            <v-btn
              v-if="!isDateBeforeCurrent(selectedDay.date)"
              color="primary"
              variant="elevated"
              block
              class="mt-2"
              :to="{
                name: 'GameResult',
                params: { teamId, scheduleId: selectedDay.schedule.id },
              }"
              @click="isDayDetailOpen = false"
            >
              {{ t('seasonPortal.gameResultInput') }}
            </v-btn>
          </template>
        </div>
        <div v-else class="text-center text-caption text-medium-emphasis py-4">
          スケジュールなし
        </div>
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import type { SeasonDetail } from '@/types/seasonDetail'
import type { SeasonSchedule } from '@/types/seasonSchedule'
import type { Team } from '@/types/team'
import SeasonRosterTab from '@/components/season/SeasonRosterTab.vue'
import SeasonAbsenceTab from '@/components/season/SeasonAbsenceTab.vue'
import EmptyState from '@/components/EmptyState.vue'
import TeamMembers from '@/views/TeamMembers.vue'
import { useTeamSelectionStore } from '@/stores/teamSelection'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const teamSelectionStore = useTeamSelectionStore()
const season = ref<SeasonDetail | null>(null)
const currentDate = ref(new Date())

const teamId = parseInt(<string>route.params.teamId, 10)

// タブ状態をURLクエリパラメータで管理
const activeTab = ref((route.query.tab as string) || 'calendar')

watch(activeTab, (newTab) => {
  if (newTab === 'stats') {
    router.push({ name: '成績集計' })
    return
  }
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

// ビュー切替 (localStorageで記憶)
const viewMode = ref<'calendar' | 'table'>(
  (localStorage.getItem('sp_view') as 'calendar' | 'table') || 'calendar',
)
watch(viewMode, (v) => localStorage.setItem('sp_view', v))

// 表ビューフィルタ
const tableFilter = ref<'all' | 'game'>('all')

// 日程詳細ダイアログ
type CalendarDay = {
  date: Date
  isCurrentMonth: boolean
  isCurrentDay: boolean
  isWeekend: boolean
  dayOfWeek: number
  schedule: SeasonSchedule | null | undefined
}
const isDayDetailOpen = ref(false)
const selectedDay = ref<CalendarDay | null>(null)

const openDayDetail = (day: CalendarDay) => {
  if (!day.isCurrentMonth) return
  selectedDay.value = day
  isDayDetailOpen.value = true
}

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

const currentDateStr = computed(() => {
  return currentDate.value.toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' })
})

const monthStr = computed(() => {
  return currentDate.value.toLocaleDateString('ja-JP', { year: 'numeric', month: 'long' })
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

  const days: CalendarDay[] = []
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

    const schedule = season.value?.season_schedules.find((s) => {
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
  { type: 'travel_day', color: 'secondary' },
  { type: 'reserve_day', color: 'secondary' },
  { type: 'no_game_day', color: 'error' },
  { type: 'postponed', color: 'accent' },
  { type: 'no_game', color: 'success' },
]

// 日程種別カテゴリ (チップ/バッジのスタイルに使用)
const getTypeCategory = (dateType?: string) => {
  if (!dateType) return 'empty'
  if (['interleague_game_day'].includes(dateType)) return 'inter'
  if (['playoff_day'].includes(dateType)) return 'playoff'
  if (['game_day'].includes(dateType)) return 'game'
  if (['travel_day', 'interleague_reserve_day'].includes(dateType)) return 'travel'
  if (['reserve_day'].includes(dateType)) return 'reserve'
  return 'off'
}

// 雨天中止等のキャンセル系date_typeか判定
const isCancelledType = (dateType?: string) => {
  if (!dateType) return false
  return ['no_game', 'postponed'].includes(dateType)
}

// 試合系date_typeか判定
const isGameType = (dateType?: string) => {
  if (!dateType) return false
  return ['game_day', 'interleague_game_day', 'playoff_day', 'no_game'].includes(dateType)
}

// 勝敗マーク
const resultMark = (result: string) => {
  return ({ win: '○', lose: '●', draw: '△' } as Record<string, string>)[result] || ''
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

// 表ビュー: 当月の全日を行として生成
const tableRows = computed(() => calendarDays.value.filter((d) => d.isCurrentMonth))

const filteredTableRows = computed(() => {
  if (tableFilter.value === 'game') {
    return tableRows.value.filter((d) => isGameType(d.schedule?.date_type))
  }
  return tableRows.value
})

const DOW_LABELS = ['日', '月', '火', '水', '木', '金', '土']
const getDowLabel = (dow: number) => DOW_LABELS[dow]
const getDowClass = (dow: number) => {
  if (dow === 0) return 'sun-text'
  if (dow === 6) return 'sat-text'
  return ''
}

const formatTableDate = (date: Date) => {
  return date.toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric' })
}

const formatDetailDate = (date: Date) => {
  const dow = DOW_LABELS[date.getDay()]
  return date.toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' }) + `（${dow}）`
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
/* ===== カレンダーツールバー ===== */
.cal-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 8px;
}
.month-nav {
  display: flex;
  align-items: center;
  gap: 8px;
}
.month-label {
  font-size: 1.2rem;
  font-weight: 700;
  min-width: 130px;
  text-align: center;
}

/* ===== カレンダーグリッド ===== */
.cal-wrapper {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  border-radius: 8px;
  overflow: hidden;
}

.calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 0;
}

.weekday-header {
  background-color: rgb(var(--v-theme-surface-variant));
  color: rgb(var(--v-theme-on-surface-variant));
  padding: 6px 2px;
  font-size: 0.85rem;
  font-weight: 700;
  border-bottom: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  text-align: center;
}
.sat-header {
  color: #2563eb;
}
.sun-header {
  color: rgb(var(--v-theme-error));
}

.day-cell {
  border: 1px solid rgba(var(--v-border-color), 0.12);
  padding: 5px;
  min-height: 95px;
  position: relative;
  cursor: pointer;
  transition: background 0.1s;
  vertical-align: top;
  overflow: hidden;
}
.day-cell:hover {
  background-color: rgba(var(--v-theme-primary), 0.04);
}

.day-num-wrapper {
  margin-bottom: 3px;
}
.day-number {
  font-size: 1rem;
  font-weight: 600;
  width: 26px;
  height: 26px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
}
.today-circle {
  background-color: rgb(var(--v-theme-primary));
  color: #fff;
}
.sat-num {
  color: #2563eb;
}
.sun-num {
  color: rgb(var(--v-theme-error));
}

.not-current-month {
  background-color: rgb(var(--v-theme-surface-variant));
  opacity: 0.55;
  cursor: default;
}
.not-current-month:hover {
  background-color: rgb(var(--v-theme-surface-variant));
}
.saturday {
  background-color: rgba(37, 99, 235, 0.05);
}
.sunday {
  background-color: rgba(var(--v-theme-error), 0.05);
}
.is-current-day {
  outline: 2px solid rgb(var(--v-theme-primary));
  outline-offset: -2px;
}

/* ===== セルコンテンツ ===== */
.cell-content {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.type-chip {
  display: block;
  font-size: 0.78rem;
  padding: 1px 5px;
  border-radius: 3px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  width: 100%;
  cursor: pointer;
  line-height: 1.5;
  font-weight: 500;
}

/* ===== 日程種別カラー (chip/badge共通) ===== */
.chip-game,
.badge-game {
  background: rgba(var(--v-theme-primary), 0.15);
  color: rgb(var(--v-theme-primary));
  font-weight: 600;
}
.chip-inter,
.badge-inter {
  background: rgba(var(--v-theme-info), 0.15);
  color: rgb(var(--v-theme-info));
  font-weight: 600;
}
.chip-playoff,
.badge-playoff {
  background: rgba(var(--v-theme-warning), 0.2);
  color: rgb(var(--v-theme-warning));
  font-weight: 600;
}
.chip-travel,
.badge-travel {
  background: rgba(var(--v-theme-secondary), 0.15);
  color: rgb(var(--v-theme-secondary));
}
.chip-reserve,
.badge-reserve {
  background: rgba(var(--v-theme-warning), 0.12);
  color: rgb(var(--v-theme-warning));
}
.chip-off,
.badge-off {
  background: rgb(var(--v-theme-surface-variant));
  color: rgb(var(--v-theme-on-surface-variant));
}
.chip-empty,
.badge-empty {
  background: transparent;
  color: rgb(var(--v-theme-on-surface-variant));
}

/* ===== 試合情報 ===== */
.game-info {
  font-size: 0.85rem;
  line-height: 1.35;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 2px;
  color: rgb(var(--v-theme-on-surface));
}
.opponent-text {
  font-size: 0.85rem;
}
.starter-text {
  font-size: 0.8rem;
  color: rgb(var(--v-theme-on-surface-variant));
}
.score-text {
  font-size: 0.8rem;
  color: rgb(var(--v-theme-on-surface-variant));
}

.result-mark {
  font-weight: 700;
  font-size: 0.95rem;
}
.result-win {
  color: rgb(var(--v-theme-success));
}
.result-lose {
  color: rgb(var(--v-theme-error));
}
.result-draw {
  color: rgb(var(--v-theme-secondary));
}

.entry-btn {
  font-size: 0.72rem !important;
  padding: 0 4px !important;
  min-height: 18px !important;
  height: auto !important;
}

/* ===== 凡例 ===== */
.calendar-legend {
  padding: 6px 2px;
}
.legend-inner {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}
.legend-item {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 0.8rem;
  color: rgb(var(--v-theme-on-surface-variant));
}
.legend-dot {
  width: 14px;
  height: 10px;
  border-radius: 3px;
  flex-shrink: 0;
  display: inline-block;
}
.legend-results {
  display: flex;
  align-items: center;
  gap: 3px;
  font-size: 0.85rem;
}

/* ===== 表形式ビュー ===== */
.table-wrapper {
  overflow-x: auto;
}
.schedule-table {
  width: 100%;
  border-collapse: collapse;
  background: rgb(var(--v-theme-surface));
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.07);
  font-size: 0.875rem;
}
.schedule-table th {
  background: rgb(var(--v-theme-primary));
  color: #fff;
  padding: 9px 12px;
  text-align: left;
  font-size: 0.8rem;
  font-weight: 600;
  white-space: nowrap;
}
.schedule-table td {
  padding: 7px 12px;
  font-size: 0.875rem;
  border-bottom: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  vertical-align: middle;
}
.schedule-table tr:last-child td {
  border-bottom: none;
}
.schedule-table tr:hover td {
  background: rgba(var(--v-theme-primary), 0.03);
}
.today-row > td {
  background-color: rgba(var(--v-theme-primary), 0.06) !important;
}

.type-badge {
  display: inline-block;
  padding: 2px 9px;
  border-radius: 12px;
  font-size: 0.78rem;
  font-weight: 600;
  white-space: nowrap;
}

.result-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  font-size: 0.85rem;
  font-weight: 700;
}
.result-badge.result-win {
  background: rgba(var(--v-theme-success), 0.15);
  color: rgb(var(--v-theme-success));
}
.result-badge.result-lose {
  background: rgba(var(--v-theme-error), 0.15);
  color: rgb(var(--v-theme-error));
}
.result-badge.result-draw {
  background: rgba(var(--v-theme-secondary), 0.15);
  color: rgb(var(--v-theme-secondary));
}

.date-cell {
  white-space: nowrap;
}
.dow-cell {
  white-space: nowrap;
}
.sat-text {
  color: #2563eb;
  font-weight: 600;
}
.sun-text {
  color: rgb(var(--v-theme-error));
  font-weight: 600;
}

/* ===== レスポンシブ ===== */
@media (max-width: 960px) {
  .day-cell {
    padding: 3px;
    min-height: 78px;
  }
  .day-number {
    font-size: 0.9rem;
    width: 22px;
    height: 22px;
  }
  .game-info {
    font-size: 0.8rem;
  }
}

@media (max-width: 600px) {
  .day-cell {
    padding: 2px;
    min-height: 62px;
  }
  .day-number {
    font-size: 0.85rem;
    width: 20px;
    height: 20px;
  }
  .type-chip {
    font-size: 0.65rem;
    padding: 1px 3px;
  }
  /* モバイル: 試合情報はダイアログ表示のため非表示 */
  .game-info {
    display: none;
  }
  .entry-btn {
    display: none !important;
  }
  .weekday-header {
    font-size: 0.72rem;
    padding: 4px 1px;
  }
  .month-label {
    font-size: 1rem;
    min-width: 100px;
  }
}

/* 表ビュー: モバイルはカード形式 */
@media (max-width: 768px) {
  .schedule-table thead {
    display: none;
  }
  .schedule-table,
  .schedule-table tbody,
  .schedule-table tr,
  .schedule-table td {
    display: block;
  }
  .schedule-table tr {
    background: rgb(var(--v-theme-surface));
    border-radius: 8px;
    margin-bottom: 8px;
    padding: 10px 14px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
    border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  }
  .schedule-table td {
    border-bottom: none !important;
    padding: 3px 0;
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 0.85rem;
  }
  .schedule-table td::before {
    content: attr(data-label);
    font-size: 0.78rem;
    color: rgb(var(--v-theme-on-surface-variant));
    min-width: 56px;
    flex-shrink: 0;
  }
  .today-row {
    border-color: rgb(var(--v-theme-primary)) !important;
    background: rgba(var(--v-theme-primary), 0.04) !important;
  }
}
</style>
