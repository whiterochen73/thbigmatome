<template>
  <v-container>
    <v-toolbar color="primary" density="compact">
      <template #prepend>
        <div class="d-flex align-center ml-2 flex-wrap">
          <v-btn
            variant="text"
            size="small"
            :to="seasonPortalRoute"
            class="text-white pa-1 text-caption"
            style="min-width: 0; text-decoration: underline; text-underline-offset: 2px"
          >
            {{ t('seasonPortal.title') }}
          </v-btn>
          <v-icon size="x-small" class="text-white mx-1" style="opacity: 0.7"
            >mdi-chevron-right</v-icon
          >
          <span class="text-subtitle-2 font-weight-bold text-white mx-1">{{
            gameData.team_name
          }}</span>
          <v-icon size="x-small" class="text-white mx-1" style="opacity: 0.7"
            >mdi-chevron-right</v-icon
          >
          <span class="text-subtitle-2 text-white mx-1">Game {{ gameData.game_number }}</span>
          <span class="text-caption text-white mx-1" style="opacity: 0.9">{{
            formattedGameDate
          }}</span>
        </div>
      </template>
      <template #append>
        <v-btn
          @click="saveGame"
          color="success"
          variant="flat"
          size="small"
          prepend-icon="mdi-content-save-outline"
          class="mr-2"
        >
          {{ t('gameResult.save') }}
        </v-btn>
      </template>
    </v-toolbar>

    <!-- 試合日ヘッダ: 日付・進み具合・前後の試合日への移動 -->
    <v-card variant="outlined" class="mt-2 pa-3" data-testid="game-day-head">
      <div class="d-flex flex-wrap align-center ga-4">
        <div>
          <div class="text-h6 font-weight-bold">{{ formattedGameDate }}</div>
          <div class="text-body-2 text-medium-emphasis">{{ headLine }}</div>
        </div>
        <div class="game-day-progress" role="group" :aria-label="t('gameDay.progress.label')">
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
            size="small"
            variant="outlined"
            prepend-icon="mdi-chevron-left"
            :disabled="!prevGameDay"
            data-testid="prev-game-day"
            @click="prevGameDay && goToGameDay(prevGameDay.id)"
          >
            {{ t('gameDay.nav.prev') }}
          </v-btn>
          <v-btn
            size="small"
            variant="outlined"
            append-icon="mdi-chevron-right"
            :disabled="!nextGameDay"
            data-testid="next-game-day"
            @click="nextGameDay && goToGameDay(nextGameDay.id)"
          >
            {{ t('gameDay.nav.next') }}
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

    <div class="game-day-phase text-caption mt-4 mb-1">{{ t('gameDay.phase.before') }}</div>
    <div class="d-flex flex-column ga-2">
      <GameDaySection
        no="1"
        :title="t('gameDay.sections.members')"
        :summary="t('gameDay.summary.members')"
        state="info"
        :collapsible="false"
        test-id="section-members"
      >
        <template #actions>
          <v-btn size="small" variant="outlined" :to="membersRoute" data-testid="link-members">
            {{ t('gameDay.links.members') }}
          </v-btn>
        </template>
      </GameDaySection>

      <GameDaySection
        no="2"
        :title="t('gameDay.sections.roster')"
        :summary="t('gameDay.summary.roster')"
        state="info"
        :collapsible="false"
        test-id="section-roster"
      >
        <template #actions>
          <v-btn size="small" variant="outlined" :to="rosterRoute" data-testid="link-roster">
            {{ t('gameDay.links.roster') }}
          </v-btn>
        </template>
      </GameDaySection>

      <GameDaySection
        no="3"
        :title="t('gameDay.sections.absences')"
        :summary="t('gameDay.summary.absences')"
        state="info"
        :collapsible="false"
        test-id="section-absences"
      >
        <template #actions>
          <v-btn size="small" variant="outlined" :to="absencesRoute" data-testid="link-absences">
            {{ t('gameDay.links.absences') }}
          </v-btn>
        </template>
      </GameDaySection>

      <GameDaySection
        v-model:open="openSections.setup"
        no="4"
        :title="t('gameDay.sections.setup')"
        :summary="setupSummary"
        :state="setupState"
        test-id="section-setup"
      >
        <v-row density="compact" class="mt-1">
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
            <v-text-field v-model="gameData.stadium" :label="t('gameResult.stadium')" />
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
        <div class="d-flex justify-end">
          <v-btn color="primary" variant="elevated" data-testid="save-setup" @click="saveGame">
            {{ t('gameDay.save') }}
          </v-btn>
        </div>
      </GameDaySection>
    </div>

    <div class="game-day-divider text-caption my-3">{{ t('gameDay.phase.game') }}</div>

    <div class="game-day-phase text-caption mb-1">{{ t('gameDay.phase.after') }}</div>
    <div class="d-flex flex-column ga-2">
      <GameDaySection
        v-model:open="openSections.result"
        no="5"
        :title="t('gameDay.sections.result')"
        :summary="resultSummary"
        :state="resultState"
        test-id="section-result"
      >
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
        <div class="d-flex justify-end mt-2">
          <v-btn color="primary" variant="elevated" data-testid="save-result" @click="saveGame">
            {{ t('gameDay.save') }}
          </v-btn>
        </div>
      </GameDaySection>

      <GameDaySection
        v-model:open="openSections.pitchers"
        no="6"
        :title="t('gameDay.sections.pitchers')"
        :summary="pitcherSummary"
        :state="pitcherState"
        lazy
        test-id="section-pitchers"
      >
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
      </GameDaySection>

      <GameDaySection
        v-model:open="openSections.pitcherStatus"
        no="–"
        :title="t('gameDay.sections.pitcherStatus')"
        state="info"
        lazy
        test-id="section-pitcher-status"
      >
        <PitcherStatusTab
          v-if="gameData.team_id"
          :key="`status-${scheduleId}`"
          :team-id="Number(teamId)"
          :schedule-date="gameData.game_date"
          :competition-id="gameData.competition_id ?? null"
        />
      </GameDaySection>

      <GameDaySection
        no="7"
        :title="t('gameDay.sections.inGameAbsences')"
        :summary="t('gameDay.summary.inGameAbsences')"
        state="info"
        :collapsible="false"
        test-id="section-in-game-absences"
      >
        <template #actions>
          <v-btn
            size="small"
            variant="outlined"
            :to="absencesRoute"
            data-testid="link-in-game-absences"
          >
            {{ t('gameDay.links.absences') }}
          </v-btn>
        </template>
      </GameDaySection>
    </div>

    <v-snackbar v-model="snackbar" :color="snackbarColor" :timeout="snackbarTimeout">
      {{ snackbarText }}
    </v-snackbar>

    <ConfirmDialog ref="confirmDialog" />
  </v-container>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onBeforeUnmount, computed, watch, nextTick } from 'vue'
import { useRoute, useRouter, onBeforeRouteLeave, onBeforeRouteUpdate } from 'vue-router'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import type { GameData } from '@/types/gameData'
import type { Team } from '@/types/team'
import TeamMemberSelect from '@/components/shared/TeamMemberSelect.vue'
import TeamSelect from '@/components/shared/TeamSelect.vue'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import PitcherAppearanceTab from '@/components/pitcher/PitcherAppearanceTab.vue'
import PitcherStatusTab from '@/components/pitcher/PitcherStatusTab.vue'
import GameDaySection from '@/components/gameDay/GameDaySection.vue'
import {
  detectRecordMismatch,
  hasGameDayArrived,
  hasSavedScore,
  mismatchMessageKey,
  pitcherStageState,
  progressMarks,
  resultStageState,
  setupStageState,
  type StageState,
} from '@/components/gameDay/gameDayStatus'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const gameDate = ref(new Date())
// 旧 URL のタブ名（overview / pitchers / pitcher_status）は、該当する段を開く指定として受け付ける
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
// 「選手登録・契約変更」は、シーズンポータルの「チーム編成」タブ（TeamMembers.vue）が担う
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
// 段の開閉（旧タブ名 → 開く段）
// ─────────────────────────────────────────

const openSections = reactive<Record<string, boolean>>({
  setup: false,
  result: false,
  pitchers: false,
  pitcherStatus: false,
})

const TAB_SECTIONS: Record<string, string[]> = {
  overview: ['setup', 'result'],
  pitchers: ['pitchers'],
  pitcher_status: ['pitcherStatus'],
}

const applyTab = (tab: string, scroll: boolean) => {
  const ids = TAB_SECTIONS[tab] ?? TAB_SECTIONS.overview
  ids.forEach((id) => {
    openSections[id] = true
  })
  if (scroll) scrollToSection(ids[0])
}

const SECTION_TEST_IDS: Record<string, string> = {
  setup: 'section-setup',
  result: 'section-result',
  pitchers: 'section-pitchers',
  pitcherStatus: 'section-pitcher-status',
}

const scrollToSection = (id: string) => {
  nextTick(() => {
    const el = document.querySelector(`[data-testid="${SECTION_TEST_IDS[id]}"]`)
    if (el && typeof el.scrollIntoView === 'function') el.scrollIntoView({ block: 'start' })
  })
}

applyTab(activeTab.value, false)
watch(activeTab, (tab) => applyTab(tab, true))

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
  ])

const resultSnapshot = (g: GameData) =>
  JSON.stringify([normNumber(g.score), normNumber(g.opponent_score), !!g.no_game])

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

const GAME_DAY_TYPES = ['game_day', 'interleague_game_day', 'playoff_day']

const gameDays = computed(() =>
  seasonSchedules.value
    .filter((s) => GAME_DAY_TYPES.includes(s.date_type))
    .sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0)),
)
const currentGameDayIndex = computed(() =>
  gameDays.value.findIndex((s) => String(s.id) === String(scheduleId.value)),
)
const prevGameDay = computed(() =>
  currentGameDayIndex.value > 0 ? gameDays.value[currentGameDayIndex.value - 1] : null,
)
const nextGameDay = computed(() =>
  currentGameDayIndex.value >= 0 ? (gameDays.value[currentGameDayIndex.value + 1] ?? null) : null,
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
  appearanceCount.value === null ? null : detectRecordMismatch(savedRecord.value),
)
const mismatchMessage = computed(() => {
  const key = mismatchMessageKey(mismatch.value)
  return key ? t(key) : ''
})

const progress = computed(() =>
  progressMarks([setupState.value, resultState.value, pitcherState.value]),
)

const openMismatchSection = () => {
  const id = mismatch.value === 'score_without_appearances' ? 'pitchers' : 'result'
  openSections[id] = true
  scrollToSection(id)
}

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
  [`Game ${gameData.value.game_number}`, setupSummary.value].filter(Boolean).join(' ・ '),
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
// 取得
// ─────────────────────────────────────────

let initialOpenApplied = false

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
    seasonSchedules.value = response?.data?.season_schedules ?? []
  } catch (error) {
    seasonCurrentDate.value = null
    seasonSchedules.value = []
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
  appearanceCount.value = null
  pitcherDirty.value = false
  await fetchGame()
  await Promise.all([fetchAppearanceCount(), fetchSeasonInfo()])
  // 初めて開いた時に、要確認の段は閉じたままにしない（赤い帯の行き先が見える状態にする）
  if (!initialOpenApplied) {
    initialOpenApplied = true
    if (mismatch.value)
      openSections[mismatch.value === 'score_without_appearances' ? 'pitchers' : 'result'] = true
  }
}

const showSnackbar = (text: string, color: string = 'success', timeout: number = 3000) => {
  snackbarText.value = text
  snackbarColor.value = color
  snackbarTimeout.value = timeout
  snackbar.value = true
}

const saveGame = async () => {
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
  if (next !== prev) loadAll()
})

onMounted(() => {
  loadAll()
  fetchAllTeams()
  window.addEventListener('beforeunload', onBeforeUnload)
})

onBeforeUnmount(() => {
  window.removeEventListener('beforeunload', onBeforeUnload)
})
</script>

<style scoped>
.game-day-phase {
  color: rgba(var(--v-theme-on-surface), var(--v-medium-emphasis-opacity));
  font-weight: 700;
  letter-spacing: 0.08em;
}
.game-day-divider {
  text-align: center;
  color: rgba(var(--v-theme-on-surface), var(--v-medium-emphasis-opacity));
  border-top: 1px dashed rgba(var(--v-border-color), var(--v-border-opacity));
  border-bottom: 1px dashed rgba(var(--v-border-color), var(--v-border-opacity));
  padding: 6px 0;
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
