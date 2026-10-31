<template>
  <v-container>
    <!-- 日程ヘッダ: 日付・種類・前後の日への移動 -->
    <v-card variant="outlined" class="mt-2 pa-3" data-testid="game-day-head">
      <div class="d-flex flex-wrap align-center ga-4">
        <div>
          <div class="text-h6 font-weight-bold">{{ formattedGameDate }}</div>
          <div class="text-body-2 text-medium-emphasis">{{ headLine }}</div>
        </div>
        <div class="d-flex flex-column" style="min-width: 220px">
          <v-select
            :model-value="currentDateType"
            :items="dateTypeItems"
            item-title="title"
            item-value="value"
            :label="t('gameDay.dateType.label')"
            :disabled="hasUnsavedChanges || !currentDateType || dateTypeSaving"
            :loading="dateTypeSaving"
            density="compact"
            hide-details
            data-testid="date-type-select"
            @update:model-value="updateDateType"
          />
          <span v-if="hasUnsavedChanges" class="text-caption text-medium-emphasis">{{
            t('gameDay.dateType.saveFirst')
          }}</span>
        </div>
        <div
          v-if="isGameDay"
          class="game-day-progress"
          role="group"
          :aria-label="t('gameDay.progress.label')"
        >
          <span class="text-caption">{{ t('gameDay.progress.label') }}</span>
          <span class="game-day-progress__bar" aria-hidden="true">
            <i v-for="(mark, i) in progress" :key="i" :class="`game-day-progress__cell--${mark}`" />
          </span>
          <span class="text-caption" data-testid="game-day-progress-text">{{
            t('gameDay.progress.text', {
              done: progress.filter((m) => m === 'on').length,
              total: progress.length,
            })
          }}</span>
        </div>
        <v-spacer />
        <div class="d-flex ga-2">
          <v-btn
            v-if="prevSchedule"
            size="small"
            variant="outlined"
            prepend-icon="mdi-chevron-left"
            data-testid="prev-game-day"
            @click="prevSchedule && goToGameDay(prevSchedule.id)"
          >
            {{
              `${t('gameDay.nav.prev')} ${formatScheduleDate(prevSchedule.date)} ${dateTypeLabel(prevSchedule.date_type)}`
            }}
          </v-btn>
          <v-btn
            v-if="nextSchedule"
            size="small"
            variant="outlined"
            append-icon="mdi-chevron-right"
            data-testid="next-game-day"
            @click="nextSchedule && goToGameDay(nextSchedule.id)"
          >
            {{
              `${t('gameDay.nav.next')} ${formatScheduleDate(nextSchedule.date)} ${dateTypeLabel(nextSchedule.date_type)}`
            }}
          </v-btn>
        </div>
      </div>
    </v-card>

    <!-- 要確認の帯（得点と登板記録の食い違い）。理由を 1 文で出す -->
    <v-alert
      v-if="mismatchMessage"
      type="error"
      variant="tonal"
      density="compact"
      class="mt-3"
      data-testid="mismatch-banner"
    >
      <div class="d-flex flex-wrap align-center ga-2">
        <span>{{ mismatchMessage }}</span>
        <v-spacer />
        <v-btn size="small" variant="outlined" @click="openMismatchSection">
          {{
            mismatch === 'score_without_appearances'
              ? t('gameDay.mismatch.openPitchers')
              : t('gameDay.mismatch.openResult')
          }}
        </v-btn>
      </div>
    </v-alert>

    <GameDaySteps
      :steps="steps"
      :mode="stepsMode"
      :active="activeStep"
      :open="openSections"
      @update:active="pickStep"
      @update:open="setOpen"
    >
      <!-- 埋め込んだ 4 つの画面は、シーズンポータルのタブと同じ部品を同じ props で置く（現在日基準の振る舞いも同じ） -->
      <template #body-members>
        <div class="mt-2">
          <GameDayDateNote :game-date="gameData.game_date" :current-date="seasonCurrentDate" />
          <TeamMembers :team-id="Number(teamId)" />
        </div>
      </template>

      <template #body-roster>
        <div class="mt-2">
          <GameDayDateNote :game-date="gameData.game_date" :current-date="seasonCurrentDate" />
          <SeasonRosterTab :team-id="Number(teamId)" />
        </div>
      </template>

      <template #body-absences>
        <div class="mt-2">
          <GameDayDateNote :game-date="gameData.game_date" :current-date="seasonCurrentDate" />
          <SeasonAbsenceTab :key="`absences-${embedKey.absences}`" :team-id="Number(teamId)" />
        </div>
      </template>

      <template #body-inGameAbsences>
        <div class="mt-2">
          <GameDayDateNote :game-date="gameData.game_date" :current-date="seasonCurrentDate" />
          <SeasonAbsenceTab
            :key="`in-game-absences-${embedKey.inGameAbsences}`"
            :team-id="Number(teamId)"
            default-phase="in_game"
          />
        </div>
      </template>

      <template #body-setup>
        <v-row density="compact" class="mt-1" data-testid="setup-row-main">
          <v-col cols="12" sm="6" md="4">
            <TeamMemberSelect
              v-model="gameData.announced_starter_id"
              :team-id="gameData.team_id"
              v-if="gameData.team_id"
              :label="t('gameResult.announcedStarter')"
              :starter-eligible="true"
              clearable
            />
          </v-col>
          <v-col cols="12" sm="6" md="4">
            <TeamSelect
              v-model="gameData.opponent_team_id"
              :teams="allTeams"
              display-name-type="short_name"
              :label="t('gameResult.opponentTeam')"
            />
          </v-col>
          <v-col cols="12" sm="6" md="4">
            <v-select
              v-model="gameData.home_away"
              :items="homeAwayItems"
              item-title="name"
              item-value="value"
              :label="t('gameResult.homeAway.title')"
            />
          </v-col>
          <v-col cols="12" sm="6" md="4">
            <v-text-field
              v-model="gameData.stadium"
              data-testid="stadium"
              :label="t('gameResult.stadium')"
            />
          </v-col>
          <v-col cols="12" sm="6" md="4">
            <v-select
              v-model="gameData.designated_hitter_enabled"
              :items="dhItems"
              item-title="name"
              item-value="value"
              :label="t('gameResult.dhSystem.title')"
            />
          </v-col>
        </v-row>
        <v-row density="compact" data-testid="setup-row-real">
          <v-col cols="12" sm="6" md="4">
            <v-text-field
              v-model="gameData.real_date"
              type="date"
              data-testid="real-date"
              :label="t('gameResult.realDate')"
              clearable
            />
          </v-col>
          <v-col cols="12" sm="6" md="4">
            <v-select
              v-model="gameData.real_start_time"
              :items="realStartTimeItems"
              data-testid="real-start-time"
              :label="t('gameResult.realStartTime')"
              clearable
            />
          </v-col>
          <v-col cols="12" sm="6" md="4">
            <v-select
              v-model="gameData.venue"
              :items="venueItems"
              item-title="name"
              item-value="value"
              data-testid="venue"
              :label="t('gameResult.venue.title')"
              clearable
            />
          </v-col>
        </v-row>
        <div class="d-flex justify-end">
          <v-btn color="primary" variant="elevated" data-testid="save-setup" @click="saveGame">
            {{ t('gameDay.save') }}
          </v-btn>
        </div>
      </template>

      <template #body-result>
        <v-row density="compact" class="mt-1">
          <v-col cols="6" sm="4" md="3">
            <v-text-field
              v-model.number="gameData.score"
              :label="t('gameResult.score')"
              type="number"
              min="0"
              hide-details
            />
          </v-col>
          <v-col cols="6" sm="4" md="3">
            <v-text-field
              v-model.number="gameData.opponent_score"
              :label="t('gameResult.opponentScore')"
              type="number"
              min="0"
              hide-details
            />
          </v-col>
          <v-col cols="12" sm="4" md="6">
            <v-checkbox
              v-model="gameData.no_game"
              data-testid="no-game-checkbox"
              :label="t('gameResult.noGame')"
              :hint="t('gameResult.noGameHint')"
              persistent-hint
              density="compact"
            />
          </v-col>
        </v-row>
        <div class="mt-2" data-testid="game-log">
          <div class="d-flex align-center flex-wrap ga-2 mb-1">
            <span class="text-subtitle-2">{{ t('gameResult.gameLog.title') }}</span>
            <v-btn
              size="small"
              variant="outlined"
              prepend-icon="mdi-file-upload-outline"
              data-testid="game-log-load"
              @click="gameLogFileInput?.click()"
            >
              {{ t('gameResult.gameLog.loadFile') }}
            </v-btn>
            <input
              ref="gameLogFileInput"
              type="file"
              accept=".txt,.log,text/plain"
              class="d-none"
              data-testid="game-log-file-input"
              @change="onGameLogFileChange"
            />
          </div>
          <v-textarea
            v-model="gameLogText"
            class="game-log-textarea"
            data-testid="game-log-textarea"
            rows="10"
            :auto-grow="false"
            variant="outlined"
            density="compact"
            persistent-hint
            :hint="t('gameResult.gameLog.hint')"
            :error="gameLogTooLarge"
            :error-messages="gameLogTooLarge ? [gameLogTooLargeMessage] : []"
          >
            <template #details>
              <span data-testid="game-log-counter" :class="{ 'text-error': gameLogTooLarge }">
                {{ gameLogCounter }}
              </span>
            </template>
          </v-textarea>
        </div>
        <div class="d-flex justify-end mt-2">
          <v-btn color="primary" variant="elevated" data-testid="save-result" @click="saveGame">
            {{ t('gameDay.save') }}
          </v-btn>
        </div>
      </template>

      <template #body-pitchers>
        <PitcherAppearanceTab
          v-if="gameData.team_id"
          :key="`pitchers-${scheduleId}`"
          ref="pitcherTabRef"
          :team-id="Number(teamId)"
          :game-date="gameData.game_date"
          :game-result="pitcherGameResult"
          :schedule-id="Number(scheduleId)"
          :announced-starter-id="gameData.announced_starter_id"
          :competition-id="gameData.competition_id ?? null"
          @saved="fetchAppearanceCount"
          @dirty-change="pitcherDirty = $event"
        />
      </template>

      <template #body-pitcherStatus>
        <PitcherStatusTab
          v-if="gameData.team_id"
          :key="`status-${scheduleId}`"
          :team-id="Number(teamId)"
          :schedule-date="gameData.game_date"
          :competition-id="gameData.competition_id ?? null"
        />
      </template>
    </GameDaySteps>

    <v-snackbar v-model="snackbar" :color="snackbarColor" :timeout="snackbarTimeout">
      {{ snackbarText }}
    </v-snackbar>

    <ConfirmDialog ref="confirmDialog" />
  </v-container>
</template>

<script setup lang="ts">
import {
  ref,
  reactive,
  onMounted,
  onBeforeUnmount,
  computed,
  watch,
  watchEffect,
  nextTick,
} from 'vue'
import { useRoute, useRouter, onBeforeRouteLeave, onBeforeRouteUpdate } from 'vue-router'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import { useDisplay } from 'vuetify'
import type { GameData } from '@/types/gameData'
import type { Team } from '@/types/team'
import TeamMemberSelect from '@/components/shared/TeamMemberSelect.vue'
import TeamSelect from '@/components/shared/TeamSelect.vue'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import PitcherAppearanceTab from '@/components/pitcher/PitcherAppearanceTab.vue'
import PitcherStatusTab from '@/components/pitcher/PitcherStatusTab.vue'
import TeamMembers from '@/views/TeamMembers.vue'
import SeasonRosterTab from '@/components/season/SeasonRosterTab.vue'
import SeasonAbsenceTab from '@/components/season/SeasonAbsenceTab.vue'
import GameDaySteps, { type GameDayStep } from '@/components/gameDay/GameDaySteps.vue'
import GameDayDateNote from '@/components/gameDay/GameDayDateNote.vue'
import { setAppBarBreadcrumbs, clearAppBarBreadcrumbs } from '@/composables/useAppBarBreadcrumbs'
import {
  GAME_LOG_MAX_BYTES,
  GAME_LOG_FILE_READ_MAX_BYTES,
  gameLogByteLength,
  decodeGameLogBytes,
} from '@/components/gameDay/gameLog'
import {
  detectRecordMismatch,
  hasGameDayArrived,
  hasSavedScore,
  isGameType,
  mismatchMessageKey,
  pitcherStageState,
  progressMarks,
  resultStageState,
  setupStageState,
  SCHEDULE_DATE_TYPES,
  type StageState,
} from '@/components/gameDay/gameDayStatus'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const gameDate = ref(new Date())
// 旧 URL のタブ名（overview / pitchers / pitcher_status）は、該当するステップ（段）を開く指定として受け付ける
const activeTab = ref((route.query.tab as string) || 'overview')

const snackbar = ref(false)
const snackbarText = ref('')
const snackbarColor = ref('success')
const snackbarTimeout = ref(3000)

// 前後の試合日へ移ると、同じ画面のまま params だけが変わる。固定値にせず route から読む
const teamId = computed(() => route.params.teamId as string)
const scheduleId = computed(() => route.params.scheduleId as string)

const defaultGameData: GameData = {
  team_id: 0,
  team_name: '',
  season_id: 0,
  game_date: '',
  game_number: 0,
  announced_starter_id: null,
  stadium: '',
  real_date: null,
  real_start_time: null,
  venue: null,
  game_log: null,
  home_away: null,
  designated_hitter_enabled: null,
  opponent_team_id: null,
  opponent_team_name: '',
  score: null,
  opponent_score: null,
  no_game: false,
  starting_lineup: null,
}

const seasonPortalRoute = computed(() => ({
  name: 'SeasonPortal',
  params: { teamId: teamId.value },
}))
// 埋め込んだ画面の補助リンク（シーズンポータルの該当タブ）。「選手登録・契約変更」は「チーム編成」タブ（TeamMembers.vue）が担う
const membersRoute = computed(() => ({
  name: 'SeasonPortal',
  params: { teamId: teamId.value },
  query: { tab: 'members' },
}))
const rosterRoute = computed(() => ({
  name: 'SeasonPortal',
  params: { teamId: teamId.value },
  query: { tab: 'roster' },
}))
const absencesRoute = computed(() => ({
  name: 'SeasonPortal',
  params: { teamId: teamId.value },
  query: { tab: 'absences' },
}))

const gameData = ref<GameData>(defaultGameData)
const pitcherTabRef = ref<InstanceType<typeof PitcherAppearanceTab> | null>(null)
const confirmDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null)
const allTeams = ref<Team[]>([])

const homeAwayItems = [
  { name: t('gameResult.homeAway.home'), value: 'home' },
  { name: t('gameResult.homeAway.away'), value: 'visitor' },
]

// 開始時刻は 30 分刻み（00:00〜23:30）。サーバ側も同じ形式だけを受け付ける
const realStartTimeItems = Array.from({ length: 48 }, (_, i) => {
  const hour = String(Math.floor(i / 2)).padStart(2, '0')
  return `${hour}:${i % 2 === 0 ? '00' : '30'}`
})

// 開催球場（IRC のチャンネル）。ゲーム内の球場（stadium）とは別
const venueItems = (['ch1', 'ch2', 'ch3', 'ch4', 'ch5', 'tlb'] as const).map((value) => ({
  name: t(`gameResult.venue.${value}`),
  value,
}))

const dhItems = [
  { name: t('gameResult.dhSystem.enabled'), value: true },
  { name: t('gameResult.dhSystem.disabled'), value: false },
]

// ノーゲームは得点では表せないので、試合概要の no_game を先に見る（投手の休養は KO・ノーゲームの表を使う）
const pitcherGameResult = computed<'win' | 'lose' | 'draw' | 'no_game'>(() => {
  if (gameData.value.no_game) return 'no_game'
  const myScore = gameData.value.score
  const oppScore = gameData.value.opponent_score
  if (myScore === null || oppScore === null) return 'draw'
  if (myScore === oppScore) return 'draw'
  return myScore > oppScore ? 'win' : 'lose'
})

watch(
  () => gameData.value.opponent_team_id,
  (newOpponentId) => {
    if (newOpponentId) {
      const opponentTeam = allTeams.value.find((team) => team.id === newOpponentId)
      if (opponentTeam) {
        gameData.value.opponent_team_name = opponentTeam.short_name
      }
    } else {
      gameData.value.opponent_team_name = ''
    }
  },
)

// ─────────────────────────────────────────
// 保存済みの値・未保存の入力
// ─────────────────────────────────────────

interface SavedFields {
  announcedStarterId: number | null
  opponentTeamId: number | null
  score: number | null
  opponentScore: number | null
  noGame: boolean
}

// 画面の数値欄は空欄を '' で持つ。保存済みとの比較・判定では null にそろえる
const normNumber = (value: unknown): number | null =>
  value === null || value === undefined || value === '' || !Number.isFinite(Number(value))
    ? null
    : Number(value)

const setupSnapshot = (g: GameData) =>
  JSON.stringify([
    g.announced_starter_id ?? null,
    g.opponent_team_id ?? null,
    g.home_away ?? null,
    g.designated_hitter_enabled ?? null,
    g.stadium || null,
    g.real_date || null,
    g.real_start_time || null,
    g.venue || null,
  ])

// 試合ログは結果の段に置く。空文字と null は同じ（サーバも空文字を null で保存する）
const resultSnapshot = (g: GameData) =>
  JSON.stringify([
    normNumber(g.score),
    normNumber(g.opponent_score),
    !!g.no_game,
    g.game_log || null,
  ])

const baseline = reactive({
  setup: setupSnapshot(defaultGameData),
  result: resultSnapshot(defaultGameData),
})
const savedFields = ref<SavedFields>({
  announcedStarterId: null,
  opponentTeamId: null,
  score: null,
  opponentScore: null,
  noGame: false,
})

// 読み込み・保存に成功した時点の値を「保存済み」にする
const takeBaseline = () => {
  const g = gameData.value
  baseline.setup = setupSnapshot(g)
  baseline.result = resultSnapshot(g)
  savedFields.value = {
    announcedStarterId: g.announced_starter_id ?? null,
    opponentTeamId: g.opponent_team_id ?? null,
    score: normNumber(g.score),
    opponentScore: normNumber(g.opponent_score),
    noGame: !!g.no_game,
  }
}

const setupDirty = computed(() => setupSnapshot(gameData.value) !== baseline.setup)
const resultDirty = computed(() => resultSnapshot(gameData.value) !== baseline.result)
const pitcherDirty = ref(false)
const hasUnsavedChanges = computed(
  () => setupDirty.value || resultDirty.value || pitcherDirty.value,
)

// ─────────────────────────────────────────
// 登板記録の件数・シーズンの現在日と試合日の並び
// ─────────────────────────────────────────

// null = まだ取れていない／取得に失敗（件数が分からない時に「登板記録なし」の赤を出さないため）
const appearanceCount = ref<number | null>(null)

interface SeasonScheduleLite {
  id: number
  date: string
  date_type: string
}
const seasonCurrentDate = ref<string | null>(null)
const seasonSchedules = ref<SeasonScheduleLite[]>([])
const currentDateType = ref('')
const dateTypeSaving = ref(false)
const dateTypeItems = computed(() =>
  SCHEDULE_DATE_TYPES.map((value) => ({
    value,
    title: t(`settings.schedule.dateTypes.${value}`),
  })),
)
const dateTypeLabel = (value: string) => t(`settings.schedule.dateTypes.${value}`)
const formatScheduleDate = (value: string) => {
  const [, month, day] = value.slice(0, 10).split('-')
  return `${Number(month)}/${Number(day)}`
}
// 日程の取得前は既存の試合入力画面を表示し、取得後に種類に合わせて切り替える
const isGameDay = computed(() => !currentDateType.value || isGameType(currentDateType.value))
const sortedSchedules = computed(() =>
  [...seasonSchedules.value].sort((a, b) => a.date.localeCompare(b.date) || a.id - b.id),
)
const currentScheduleIndex = computed(() =>
  sortedSchedules.value.findIndex((s) => String(s.id) === String(scheduleId.value)),
)
const prevSchedule = computed(() =>
  currentScheduleIndex.value > 0 ? sortedSchedules.value[currentScheduleIndex.value - 1] : null,
)
const nextSchedule = computed(() =>
  currentScheduleIndex.value >= 0
    ? (sortedSchedules.value[currentScheduleIndex.value + 1] ?? null)
    : null,
)

// 試合日が来るまでは入力を急かさない（黄色にしない）。現在日が取れない時も来ていない扱い
const arrived = computed(() => hasGameDayArrived(gameData.value.game_date, seasonCurrentDate.value))

// ─────────────────────────────────────────
// 段ごとの状態（判定は gameDayStatus.ts の純関数）
// ─────────────────────────────────────────

const savedRecord = computed(() => ({
  score: savedFields.value.score,
  opponentScore: savedFields.value.opponentScore,
  noGame: savedFields.value.noGame,
  appearanceCount: appearanceCount.value ?? 0,
}))

const resultSaved = computed(
  () =>
    savedFields.value.noGame ||
    hasSavedScore(savedFields.value.score, savedFields.value.opponentScore),
)

const setupState = computed<StageState>(() =>
  setupStageState(
    {
      announcedStarterId: savedFields.value.announcedStarterId,
      opponentTeamId: savedFields.value.opponentTeamId,
      resultSaved: resultSaved.value,
    },
    { dirty: setupDirty.value, arrived: arrived.value },
  ),
)

const resultState = computed<StageState>(() =>
  resultStageState(savedRecord.value, { dirty: resultDirty.value, arrived: arrived.value }),
)

const pitcherState = computed<StageState>(() =>
  appearanceCount.value === null
    ? 'info'
    : pitcherStageState(savedRecord.value, {
        dirty: pitcherDirty.value,
        arrived: arrived.value,
      }),
)

const mismatch = computed(() =>
  !isGameDay.value || appearanceCount.value === null
    ? null
    : detectRecordMismatch(savedRecord.value),
)
const mismatchMessage = computed(() => {
  const key = mismatchMessageKey(mismatch.value)
  return key ? t(key) : ''
})

const progress = computed(() =>
  progressMarks([setupState.value, resultState.value, pitcherState.value]),
)

// ─────────────────────────────────────────
// 表示用の文
// ─────────────────────────────────────────

const homeAwayLabel = computed(() => {
  if (gameData.value.home_away === 'home') return t('gameResult.homeAway.home')
  if (gameData.value.home_away === 'visitor') return t('gameResult.homeAway.away')
  return ''
})

const dhLabel = computed(() => {
  const dh = gameData.value.designated_hitter_enabled
  if (dh === null || dh === undefined) return ''
  return `${t('gameResult.dhSystem.title')}${dh ? t('gameResult.dhSystem.enabled') : t('gameResult.dhSystem.disabled')}`
})

const opponentName = computed(() => {
  const g = gameData.value as GameData & { opponent_team?: string | null }
  return g.opponent_team_name || g.opponent_team || ''
})

const setupSummary = computed(() =>
  [
    opponentName.value ? t('gameDay.summary.vsOpponent', { name: opponentName.value }) : '',
    homeAwayLabel.value,
    dhLabel.value,
  ]
    .filter(Boolean)
    .join(' ・ '),
)

const headLine = computed(() =>
  isGameDay.value
    ? [`Game ${gameData.value.game_number}`, setupSummary.value].filter(Boolean).join(' ・ ')
    : dateTypeLabel(currentDateType.value),
)

const resultSummary = computed(() => {
  if (savedFields.value.noGame) return t('gameDay.summary.noGame')
  if (!hasSavedScore(savedFields.value.score, savedFields.value.opponentScore)) return ''
  return `${savedFields.value.score} - ${savedFields.value.opponentScore}`
})

const pitcherSummary = computed(() =>
  appearanceCount.value ? t('gameDay.summary.pitcherCount', { count: appearanceCount.value }) : '',
)

// ─────────────────────────────────────────
// ステップ（PC 幅 = ステッパー + タブ、スマホ幅 = 縦積みの折りたたみ）
// どちらの形も、同じ steps・同じ状態から描く（判定は上の computed と gameDayStatus.ts）
// ─────────────────────────────────────────

// md 以上（960px〜）はステッパー。ステップ 7 つ + 状態の文字が 1 行に収まる幅の下限。それより狭い幅（スマホ・縦持ちのタブレット）は縦積み
const { mdAndUp } = useDisplay()
const stepsMode = computed<'tabs' | 'stack'>(() => (mdAndUp.value ? 'tabs' : 'stack'))

const steps = computed<GameDayStep[]>(() => {
  const allSteps: GameDayStep[] = [
    {
      id: 'members',
      slug: 'members',
      group: 'registration',
      no: 1,
      icon: 'mdi-account-multiple-plus-outline',
      title: t('gameDay.sections.members'),
      summary: t('gameDay.summary.members'),
      state: 'info',
      hasBody: true,
      lazy: true,
      link: { to: membersRoute.value, label: t('gameDay.links.members'), testId: 'link-members' },
    },
    {
      id: 'roster',
      slug: 'roster',
      group: 'registration',
      no: 2,
      icon: 'mdi-swap-vertical-bold',
      title: t('gameDay.sections.roster'),
      summary: t('gameDay.summary.roster'),
      state: 'info',
      hasBody: true,
      lazy: true,
      link: { to: rosterRoute.value, label: t('gameDay.links.roster'), testId: 'link-roster' },
    },
    {
      id: 'absences',
      slug: 'absences',
      group: 'registration',
      no: 3,
      icon: 'mdi-bandage',
      title: t('gameDay.sections.absences'),
      summary: t('gameDay.summary.absences'),
      state: 'info',
      hasBody: true,
      lazy: true,
      link: {
        to: absencesRoute.value,
        label: t('gameDay.links.absences'),
        testId: 'link-absences',
      },
    },
    {
      id: 'setup',
      slug: 'setup',
      group: 'game',
      no: 4,
      icon: 'mdi-clipboard-list-outline',
      title: t('gameDay.sections.setup'),
      summary: setupSummary.value,
      state: setupState.value,
      hasBody: true,
    },
    {
      id: 'result',
      slug: 'result',
      group: 'game',
      no: 5,
      icon: 'mdi-scoreboard-outline',
      title: t('gameDay.sections.result'),
      summary: resultSummary.value,
      state: resultState.value,
      hasBody: true,
    },
    {
      id: 'pitchers',
      slug: 'pitchers',
      group: 'game',
      no: 6,
      icon: 'mdi-baseball',
      title: t('gameDay.sections.pitchers'),
      summary: pitcherSummary.value,
      state: pitcherState.value,
      hasBody: true,
      lazy: true,
      sub: {
        id: 'pitcherStatus',
        slug: 'pitcher-status',
        title: t('gameDay.sections.pitcherStatus'),
      },
    },
    {
      id: 'inGameAbsences',
      slug: 'in-game-absences',
      group: 'game',
      no: 7,
      icon: 'mdi-ambulance',
      title: t('gameDay.sections.inGameAbsences'),
      summary: t('gameDay.summary.inGameAbsences'),
      state: 'info',
      hasBody: true,
      lazy: true,
      link: {
        to: absencesRoute.value,
        label: t('gameDay.links.absences'),
        testId: 'link-in-game-absences',
      },
    },
  ]
  return allSteps.filter((step) => isGameDay.value || step.group === 'registration')
})

// 選択中のステップ（PC 幅）と、開いている段（スマホ幅）。ステップを選ぶと同じ段も開くので、幅が変わっても選んでいた場所が開く
// （PC 幅 → スマホ幅で段が開く。逆のスマホ幅 → PC 幅は、段の開閉からは選択中のステップを決めず、PC 幅で最後に選んだステップのまま）
const activeStep = ref('result')
const openSections = reactive<Record<string, boolean>>({
  members: false,
  roster: false,
  absences: false,
  setup: false,
  result: false,
  pitchers: false,
  pitcherStatus: false,
  inGameAbsences: false,
})

// 離脱者の画面は、埋め込みが 2 か所（離脱者・試合中の負傷）ある。片方で保存した結果がもう片方に反映されるよう、
// 開く／選ぶたびに作り直して取り直す（保存はダイアログで即時に行うので、未保存の入力は無い）
const embedKey = reactive({ absences: 0, inGameAbsences: 0 })
const refreshEmbedded = (id: string) => {
  if (id === 'absences' || id === 'inGameAbsences') embedKey[id] += 1
}

const setOpen = (id: string, value: boolean) => {
  openSections[id] = value
  if (value) refreshEmbedded(id)
}

// 旧タブ名 → スマホ幅で開く段
const TAB_OPEN: Record<string, string[]> = {
  overview: ['setup', 'result'],
  pitchers: ['pitchers'],
  pitcher_status: ['pitcherStatus'],
}

const stateOf = (id: string) => steps.value.find((s) => s.id === id)?.state

// 候補の中で、要確認（赤）を先に、次に最初の未入力・編集中のステップ。無ければ undefined
const attentionStep = (candidates: string[]): string | undefined =>
  candidates.find((id) => stateOf(id) === 'warn') ??
  candidates.find((id) => stateOf(id) === 'todo' || stateOf(id) === 'editing')

// 旧タブ名が指すステップ。overview は 予告先発・対戦設定 と 結果 のうち、手の要る方（無ければ結果）
const stepForTab = (tab: string): string =>
  tab === 'pitchers' || tab === 'pitcher_status'
    ? 'pitchers'
    : (attentionStep(['setup', 'result']) ?? 'result')

const scrollToSection = (id: string) => {
  nextTick(() => {
    const slug =
      id === 'pitcherStatus' ? 'pitcher-status' : (steps.value.find((s) => s.id === id)?.slug ?? id)
    const el = document.querySelector(`[data-testid="section-${slug}"]`)
    if (el && typeof el.scrollIntoView === 'function') el.scrollIntoView({ block: 'start' })
  })
}

// ユーザーが自分でステップを選んだら、読み込み後の自動選択で上書きしない
let userPicked = false
// URL の ?tab 指定。最初の読み込みで一度だけ使う
let tabIntent: string | null = (route.query.tab as string) || null

// ステップを選ぶ（PC 幅）。縦積み側の同じ段も開く
const pickStep = (id: string) => {
  userPicked = true
  activeStep.value = id
  openSections[id] = true
  refreshEmbedded(id)
}

// 赤い帯のボタンなど、プログラムから特定のステップへ移す
const focusStep = (id: string) => {
  pickStep(id)
  if (stepsMode.value === 'stack') scrollToSection(id)
}

const openMismatchSection = () => {
  focusStep(mismatch.value === 'score_without_appearances' ? 'pitchers' : 'result')
}

const applyTab = (tab: string, scroll: boolean) => {
  if (!isGameDay.value) {
    activeStep.value = 'members'
    openSections.members = true
    return
  }
  const ids = TAB_OPEN[tab] ?? TAB_OPEN.overview
  ids.forEach((id) => {
    openSections[id] = true
  })
  activeStep.value = stepForTab(tab)
  if (scroll && stepsMode.value === 'stack') scrollToSection(ids[0])
}

// 読み込み後の初期ステップ: ?tab 指定 > 最初の要確認・未入力 > 結果。スマホ幅ではその段を開く
const resolveInitialStep = () => {
  const intent = tabIntent
  tabIntent = null
  if (!isGameDay.value) {
    activeStep.value = 'members'
    openSections.members = true
    return
  }
  const id = intent
    ? stepForTab(intent)
    : (attentionStep(['setup', 'result', 'pitchers']) ?? 'result')
  if (!userPicked) activeStep.value = id
  openSections[id] = true
  // 要確認の段は閉じたままにしない（赤い帯の行き先が見える状態にする）
  if (mismatch.value)
    openSections[mismatch.value === 'score_without_appearances' ? 'pitchers' : 'result'] = true
}

watch(activeTab, (tab) => applyTab(tab, true))

// 幅が変わると描き直されるので、登板記録の未保存の編集は失われる。ガードが空振りしないよう印を戻す
watch(stepsMode, () => {
  pitcherDirty.value = false
})

// ─────────────────────────────────────────
// 取得
// ─────────────────────────────────────────

const fetchGame = async () => {
  try {
    const response = await axios.get(`/game/${scheduleId.value}`)
    gameData.value = response.data
    if (gameData.value) {
      gameDate.value = new Date(gameData.value.game_date)
      takeBaseline()
    }
  } catch (error) {
    console.error('Failed to fetch season data:', error)
  }
}

const fetchAppearanceCount = async () => {
  if (!gameData.value.team_id || !gameData.value.game_date) return
  try {
    const response = await axios.get<unknown[]>('/pitcher_appearances', {
      params: { team_id: gameData.value.team_id, schedule_date: gameData.value.game_date },
    })
    appearanceCount.value = Array.isArray(response?.data) ? response.data.length : null
  } catch (error) {
    appearanceCount.value = null
    console.error('Failed to fetch pitcher appearances:', error)
  }
}

const fetchSeasonInfo = async () => {
  try {
    const response = await axios.get(`/teams/${teamId.value}/season`)
    seasonCurrentDate.value = response?.data?.current_date ?? null
    seasonSchedules.value = (response?.data?.season_schedules ?? []).map(
      (schedule: SeasonScheduleLite) => ({ ...schedule }),
    )
    currentDateType.value =
      seasonSchedules.value.find((s) => String(s.id) === String(scheduleId.value))?.date_type ?? ''
  } catch (error) {
    seasonCurrentDate.value = null
    seasonSchedules.value = []
    currentDateType.value = ''
    console.error('Failed to fetch season info:', error)
  }
}

const fetchAllTeams = async () => {
  try {
    const response = await axios.get('/teams')
    allTeams.value = response.data
  } catch (error) {
    console.error('Failed to fetch teams:', error)
  }
}

const loadAll = async () => {
  currentDateType.value = ''
  appearanceCount.value = null
  pitcherDirty.value = false
  await fetchGame()
  await Promise.all([fetchAppearanceCount(), fetchSeasonInfo()])
  if (!userPicked) applyTab(activeTab.value, false)
  resolveInitialStep()
}

const showSnackbar = (text: string, color: string = 'success', timeout: number = 3000) => {
  snackbarText.value = text
  snackbarColor.value = color
  snackbarTimeout.value = timeout
  snackbar.value = true
}

// ─────────────────────────────────────────
// 試合ログ（原文を保存するだけ。解析はしない）
// ─────────────────────────────────────────

const gameLogFileInput = ref<HTMLInputElement | null>(null)
// 画面の入力欄は空欄を '' で持ち、保存では空文字を null にそろえる（サーバも空文字は null にする）
const gameLogText = computed<string>({
  get: () => gameData.value.game_log ?? '',
  set: (value) => {
    gameData.value.game_log = value ? value : null
  },
})
const gameLogBytes = computed(() => gameLogByteLength(gameLogText.value))
const gameLogTooLarge = computed(() => gameLogBytes.value > GAME_LOG_MAX_BYTES)
const formatCount = (n: number) => n.toLocaleString('ja-JP')
const gameLogCounter = computed(() =>
  t('gameResult.gameLog.counter', {
    chars: formatCount(gameLogText.value.length),
    bytes: formatCount(gameLogBytes.value),
    limit: formatCount(GAME_LOG_MAX_BYTES),
  }),
)
const gameLogTooLargeMessage = computed(() =>
  t('gameResult.gameLog.tooLarge', {
    limit: formatCount(GAME_LOG_MAX_BYTES),
    bytes: formatCount(gameLogBytes.value),
  }),
)

// ファイルをブラウザの中で読み、試合ログの欄を置き換える（追記ではない）。
// IRC のログは Shift_JIS / ISO-2022-JP のことがあるため、文字コードは中身から判別する
const onGameLogFileChange = async (event: Event) => {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  // 同じファイルをもう一度選んでも change が起きるよう、選択を空に戻す
  const resetInput = () => {
    try {
      input.value = ''
    } catch {
      // 読み込みの成否に関わらないので無視する
    }
  }
  if (!file) return
  try {
    if (file.size > GAME_LOG_FILE_READ_MAX_BYTES) {
      showSnackbar(
        t('gameResult.gameLog.fileTooLarge', { limit: GAME_LOG_FILE_READ_MAX_BYTES / 1024 / 1024 }),
        'error',
      )
      return
    }
    const decoded = decodeGameLogBytes(new Uint8Array(await file.arrayBuffer()))
    if (!decoded.ok) {
      showSnackbar(t('gameResult.gameLog.decodeFailed'), 'error')
      return
    }
    if (gameLogText.value) {
      const ok = await confirmDialog.value?.open(
        t('gameResult.gameLog.replaceTitle'),
        t('gameResult.gameLog.replaceMessage'),
        { color: 'warning' },
      )
      if (!ok) return
    }
    gameLogText.value = decoded.text
  } catch (error) {
    console.error('Failed to read game log file:', error)
    showSnackbar(t('gameResult.gameLog.readFailed'), 'error')
  } finally {
    resetInput()
  }
}

// 保存済みの試合記録がある場合、日付種類を変えてもデータは削除されず非表示になる。
const hasSavedGameData = computed(
  () =>
    savedFields.value.score !== null ||
    savedFields.value.opponentScore !== null ||
    savedFields.value.noGame ||
    (appearanceCount.value ?? 0) > 0,
)

const updateDateType = async (nextType: string) => {
  const previous = currentDateType.value
  if (!previous || nextType === previous || hasUnsavedChanges.value || dateTypeSaving.value) return
  if (!SCHEDULE_DATE_TYPES.some((type) => type === nextType)) return
  if (isGameType(previous) && !isGameType(nextType) && hasSavedGameData.value) {
    const accepted = await confirmDialog.value?.open(
      t('gameDay.dateType.confirmTitle'),
      t('gameDay.dateType.confirmMessage'),
      { color: 'warning' },
    )
    if (!accepted) return
  }
  dateTypeSaving.value = true
  try {
    await axios.patch(`/teams/${teamId.value}/season/season_schedules/${scheduleId.value}`, {
      season_schedule: { date_type: nextType },
    })
    currentDateType.value = nextType
    const schedule = seasonSchedules.value.find((s) => String(s.id) === String(scheduleId.value))
    if (schedule) schedule.date_type = nextType
    if (!isGameDay.value) {
      activeStep.value = 'members'
      openSections.members = true
    }
  } catch (error) {
    console.error('Failed to update schedule:', error)
    currentDateType.value = previous
    showSnackbar(t('gameDay.dateType.saveFailed'), 'error')
  } finally {
    dateTypeSaving.value = false
  }
}

const saveGame = async () => {
  // 上限を超えたログはサーバが 422 で弾き、ほかの項目も保存されない。送る前に画面で知らせて止める
  if (gameLogTooLarge.value) {
    showSnackbar(gameLogTooLargeMessage.value, 'error', 8000)
    return
  }
  try {
    const response = await axios.put(`/game/${scheduleId.value}`, gameData.value)
    takeBaseline()
    // 得点・ノーゲームの保存でサーバが登板記録の区分を作り直す。登板記録タブを開いていれば保存済みの区分を取り直す
    await pitcherTabRef.value?.refreshSavedResultCategories?.()
    // 得点は保存できたが、投手の判定（result_category）の作り直しだけ失敗した時は警告で知らせる
    const warnings: string[] = response?.data?.warnings ?? []
    if (warnings.length > 0) {
      showSnackbar(t('gameResult.pitcherRebuildFailed'), 'warning', 10000)
    } else {
      showSnackbar(t('gameResult.saveSuccess'))
    }
  } catch (error) {
    console.error('Failed to save game data:', error)
    showSnackbar(t('gameResult.saveFailed'), 'error')
  }
}

const formattedGameDate = computed(() => {
  const date = new Date(gameData.value.game_date)
  const month = date.getMonth() + 1
  const day = date.getDate()
  const weekday = date.toLocaleDateString('ja-JP', { weekday: 'short' })
  return t('gameResult.dateDisplay', { month, day, weekday })
})

const breadcrumbOwner = Symbol('game-day')
watchEffect(() => {
  setAppBarBreadcrumbs(breadcrumbOwner, {
    seasonPortalRoute: seasonPortalRoute.value,
    teamName: gameData.value.team_name,
    gameNumber: isGameDay.value ? gameData.value.game_number : null,
    date: formattedGameDate.value,
  })
})

// ─────────────────────────────────────────
// 離脱ガード・試合日の移動
// ─────────────────────────────────────────

// 未保存の入力がある時、離れる前に確認する（ブラウザのタブを閉じる・再読み込みは beforeunload）
const confirmDiscard = async (): Promise<boolean> => {
  if (!hasUnsavedChanges.value) return true
  const ok = await confirmDialog.value?.open(
    t('gameDay.leaveConfirm.title'),
    t('gameDay.leaveConfirm.message'),
    { color: 'warning' },
  )
  return ok ?? true
}

onBeforeRouteLeave(confirmDiscard)
// 前後の試合日への移動は同じ画面のまま params だけが変わるので、こちらでも確認する
onBeforeRouteUpdate(confirmDiscard)

const onBeforeUnload = (event: BeforeUnloadEvent) => {
  if (!hasUnsavedChanges.value) return
  event.preventDefault()
  event.returnValue = ''
}

// 次の試合日へ移る時にも、要確認が残っていれば同じ理由を出す
const goToGameDay = async (id: number) => {
  if (mismatch.value) {
    const ok = await confirmDialog.value?.open(
      t('gameDay.moveConfirm.title'),
      `${mismatchMessage.value}\n${t('gameDay.moveConfirm.suffix')}`,
      { color: 'warning' },
    )
    if (!ok) return
  }
  router.push({ name: 'GameResult', params: { teamId: teamId.value, scheduleId: String(id) } })
}

watch(scheduleId, (next, prev) => {
  if (next === prev) return
  // 別の試合日へ移ったら、その日の最初の要確認・未入力のステップを選び直す
  userPicked = false
  loadAll()
})

onMounted(() => {
  loadAll()
  fetchAllTeams()
  window.addEventListener('beforeunload', onBeforeUnload)
})

onBeforeUnmount(() => {
  window.removeEventListener('beforeunload', onBeforeUnload)
  clearAppBarBreadcrumbs(breadcrumbOwner)
})
</script>

<style scoped>
.game-log-textarea :deep(textarea) {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, 'Courier New', monospace;
  font-size: 0.85rem;
  line-height: 1.4;
}
.game-day-progress {
  display: flex;
  align-items: center;
  gap: 8px;
}
.game-day-progress__bar {
  display: flex;
  gap: 3px;
}
.game-day-progress__bar i {
  display: block;
  width: 22px;
  height: 6px;
  border-radius: 3px;
  background: rgba(var(--v-border-color), var(--v-border-opacity));
}
.game-day-progress__bar i.game-day-progress__cell--on {
  background: rgb(var(--v-theme-success));
}
.game-day-progress__bar i.game-day-progress__cell--warn {
  background: rgb(var(--v-theme-error));
}
</style>
