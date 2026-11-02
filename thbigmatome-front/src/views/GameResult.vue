<template>
  <v-container>
    <!-- 日程ヘッダ: 日付・種類・前後の日への移動 -->
    <v-card variant="outlined" class="mt-2 pa-3" data-testid="game-day-head">
      <div class="d-flex flex-wrap align-center ga-4">
        <div>
          <div class="text-h6 font-weight-bold">{{ formattedGameDate }}</div>
          <div class="d-flex flex-wrap align-center ga-2 text-body-2">
            <button
              v-if="currentDateType"
              ref="dateTypeTrigger"
              type="button"
              class="date-type-trigger"
              :disabled="hasUnsavedChanges || dateTypeSaving"
              :aria-label="t('gameDay.dateType.change')"
              :title="t('gameDay.dateType.change')"
              data-testid="date-type-trigger"
              @click="dateTypeDialogOpen = true"
            >
              <v-chip
                data-testid="date-type-headline"
                variant="flat"
                :color="dateTypeAppearance(currentDateType).color"
                :prepend-icon="dateTypeAppearance(currentDateType).icon"
                append-icon="mdi-chevron-down"
                :class="{
                  'text-decoration-line-through': dateTypeAppearance(currentDateType).cancelled,
                }"
                >{{ dateTypeLabel(currentDateType) }}</v-chip
              >
            </button>
            <span v-if="hasUnsavedChanges" class="text-caption text-medium-emphasis">{{
              t('gameDay.dateType.saveFirst')
            }}</span>
          </div>
        </div>
        <!-- 上の段の 1 行（保存済みの値）。相手・得点・勝敗を大きく、ホーム/ビジター・DH は小さな印、予告先発を添える。決まっていないものは出さない -->
        <div
          v-if="isGameDay && gameDayHead"
          class="game-day-headline"
          data-testid="game-day-headline"
        >
          <span
            v-if="gameDayHead.opponent"
            class="game-day-headline__vs"
            data-testid="head-opponent"
            ><small>vs</small>{{ gameDayHead.opponent }}</span
          >
          <span
            v-if="gameDayHead.score"
            class="game-day-headline__score"
            data-testid="head-score"
            >{{ gameDayHead.score }}</span
          >
          <span
            v-if="gameDayHead.result"
            class="game-day-headline__result"
            :class="`game-day-headline__result--${gameDayHead.result}`"
            :data-result="gameDayHead.result"
            data-testid="head-result"
            >{{ t(`gameDay.head.result.${gameDayHead.result}`) }}</span
          >
          <span
            v-if="gameDayHead.homeAway"
            class="game-day-headline__tag"
            data-testid="head-home-away"
            ><v-icon size="small" aria-hidden="true">{{
              gameDayHead.homeAway === 'home' ? 'mdi-home' : 'mdi-airplane'
            }}</v-icon
            >{{
              gameDayHead.homeAway === 'home'
                ? t('gameResult.homeAway.home')
                : t('gameResult.homeAway.away')
            }}</span
          >
          <span
            v-if="gameDayHead.dh !== null"
            class="game-day-headline__tag"
            data-testid="head-dh"
            >{{ gameDayHead.dh ? t('gameDay.head.dhOn') : t('gameDay.head.dhOff') }}</span
          >
          <span
            v-if="gameDayHead.starter"
            class="game-day-headline__starter"
            data-testid="head-starter"
            ><v-icon size="small" aria-hidden="true">mdi-baseball</v-icon
            >{{ t('gameDay.head.starter', { name: gameDayHead.starter }) }}</span
          >
        </div>
        <div
          v-if="isGameDay"
          class="game-day-progress"
          role="group"
          :aria-label="t('gameDay.progress.label')"
        >
          <span class="game-day-progress__pills">
            <span v-for="step in progressSteps" :key="step.id" class="game-day-progress__pill">
              <GameDayStateChip :state="step.state" />
              <span>{{ step.title }}</span>
            </span>
          </span>
        </div>
        <div data-testid="game-day-nav" class="d-flex flex-wrap justify-end ga-2 ms-auto">
          <v-btn
            v-if="prevSchedule"
            size="small"
            variant="outlined"
            class="game-day-secondary"
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
            class="game-day-secondary"
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
      color="state-warn"
      variant="flat"
      density="compact"
      class="mt-3 game-day-mismatch"
      data-testid="mismatch-banner"
    >
      <div class="d-flex flex-wrap align-center ga-2">
        <span>{{ mismatchMessage }}</span>
        <v-spacer />
        <v-btn
          size="small"
          variant="outlined"
          class="game-day-mismatch__button"
          @click="openMismatchSection"
        >
          {{
            mismatch === 'score_without_appearances'
              ? t('gameDay.mismatch.openPitchers')
              : t('gameDay.mismatch.openResult')
          }}
        </v-btn>
      </div>
    </v-alert>

    <!-- 要確認の帯（1軍にいなかった投手の登板）。登板は保存してある。段の状態も要確認（赤）になる -->
    <v-alert
      v-if="rosterWarningMessage"
      type="error"
      color="state-warn"
      variant="flat"
      density="compact"
      class="mt-3 game-day-mismatch"
      data-testid="roster-banner"
    >
      <div class="d-flex flex-wrap align-center ga-2">
        <span>{{ rosterWarningMessage }}</span>
        <v-spacer />
        <v-btn
          size="small"
          variant="outlined"
          class="game-day-mismatch__button"
          @click="focusStep('pitchers')"
        >
          {{ t('gameDay.mismatch.openPitchers') }}
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
      <!-- 埋め込んだ 3 つの画面（登録・離脱）は、開いた日の日付で読み、同じ日付で保存する。操作できるのは今の範囲の日だけ。
           範囲の外の日は見るだけにして、過去分の修正はシーズン画面へ案内する -->
      <template #body-members>
        <div class="mt-2">
          <GameDayRangeNote :message="registrationNote" :to="membersRoute" />
          <TeamMembers
            :team-id="Number(teamId)"
            game-day-actions
            :as-of-date="gameDateKey"
            :readonly="!registrationOperable"
          />
        </div>
      </template>

      <template #body-roster>
        <div class="mt-2">
          <GameDayRangeNote :message="registrationNote" :to="rosterRoute" />
          <SeasonRosterTab
            :team-id="Number(teamId)"
            game-day-actions
            :as-of-date="gameDateKey"
            :readonly="!registrationOperable"
          />
        </div>
      </template>

      <template #body-absences>
        <div class="mt-2">
          <GameDayRangeNote :message="registrationNote" :to="absencesRoute" />
          <SeasonAbsenceTab
            :key="`absences-${embedKey.absences}`"
            :team-id="Number(teamId)"
            game-day-actions
            :as-of-date="gameDateKey"
            :readonly="!registrationOperable"
            @changed="fetchAbsenceState"
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
          <v-btn
            color="action"
            variant="flat"
            prepend-icon="mdi-content-save-outline"
            data-testid="save-setup"
            @click="saveGame"
          >
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
              density="compact"
              hide-details
            />
          </v-col>
        </v-row>
        <div class="mt-2" data-testid="game-log">
          <div class="d-flex align-center flex-wrap ga-2 mb-1">
            <span class="text-subtitle-2">{{ t('gameResult.gameLog.title') }}</span>
            <v-btn
              size="small"
              variant="outlined"
              class="game-day-secondary"
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
          <v-btn
            color="action"
            variant="flat"
            prepend-icon="mdi-content-save-outline"
            data-testid="save-result"
            @click="saveGame"
          >
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
    <DateTypeDialog
      v-model="dateTypeDialogOpen"
      :current="currentDateType"
      :items="dateTypeItems"
      @confirm="onDateTypeConfirm"
    />
  </v-container>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onBeforeUnmount, computed, watch, nextTick } from 'vue'
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
import GameDayStateChip from '@/components/gameDay/GameDayStateChip.vue'
import GameDayRangeNote from '@/components/gameDay/GameDayRangeNote.vue'
import DateTypeDialog from '@/components/gameDay/DateTypeDialog.vue'
import { dateTypeAppearance } from '@/components/gameDay/dateTypeAppearance'
import type { PlayerAbsence } from '@/types/playerAbsence'
import type { PitcherAppearanceRecord } from '@/types/pitcherAppearance'
import { useAppBarTitle } from '@/composables/useAppBarTitle'
import {
  GAME_LOG_MAX_BYTES,
  GAME_LOG_FILE_READ_MAX_BYTES,
  gameLogByteLength,
  decodeGameLogBytes,
} from '@/components/gameDay/gameLog'
import {
  detectRecordMismatch,
  hasGameDayArrived,
  isInCurrentRange,
  isOffRoster,
  dateKey,
  type CurrentRange,
  buildGameDayHead,
  hasSavedScore,
  isGameType,
  mismatchMessageKey,
  pitcherStageState,
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
  // 過去分の修正は、この試合日の日付でシーズン画面を開く
  query: { tab: 'members', date: gameDateKey.value },
}))
const rosterRoute = computed(() => ({
  name: 'SeasonPortal',
  params: { teamId: teamId.value },
  // 過去分の修正は、この試合日の日付でシーズン画面を開く
  query: { tab: 'roster', date: gameDateKey.value },
}))
const absencesRoute = computed(() => ({
  name: 'SeasonPortal',
  params: { teamId: teamId.value },
  // 過去分の修正は、この試合日の日付でシーズン画面を開く
  query: { tab: 'absences', date: gameDateKey.value },
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

// ─────────────────────────────────────────
// 保存済みの値・未保存の入力
// ─────────────────────────────────────────

interface SavedFields {
  announcedStarterId: number | null
  opponentTeamId: number | null
  homeAway: GameData['home_away']
  designatedHitter: boolean | null
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
  homeAway: null,
  designatedHitter: null,
  score: null,
  opponentScore: null,
  noGame: false,
})
// 上の段に出す名前（相手の短縮形・予告先発の選手名）。サーバが保存済みの値から返す
const savedHeadNames = ref({ opponentShortName: '', starterName: '' })

// 読み込み・保存に成功した時点の値を「保存済み」にする
const takeBaseline = () => {
  const g = gameData.value
  baseline.setup = setupSnapshot(g)
  baseline.result = resultSnapshot(g)
  savedFields.value = {
    announcedStarterId: g.announced_starter_id ?? null,
    opponentTeamId: g.opponent_team_id ?? null,
    homeAway: g.home_away ?? null,
    designatedHitter: g.designated_hitter_enabled ?? null,
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
// 1軍にいなかった投手の登板（その試合日の試合中。first 以外）。登板は保存済みで、要確認の帯と段の状態に出す
const offRosterAppearances = ref<Array<{ name: string; status: string }>>([])

interface SeasonScheduleLite {
  id: number
  date: string
  date_type: string
}
const seasonCurrentDate = ref<string | null>(null)
// 今の範囲（登録・離脱を操作できる日）。undefined = 取れていない／取得に失敗、null = 範囲なし（最終試合日の後）
const currentRange = ref<CurrentRange | null | undefined>(undefined)
// 範囲の取得が終わったか（取得中に「取れなかった」と案内しないため）
const currentRangeLoaded = ref(false)
const seasonSchedules = ref<SeasonScheduleLite[]>([])
const currentDateType = ref('')
// 試合日とみなす種別（サーバが返す。取得前は空。取得に失敗しても前の値を残す）
const gameDateTypes = ref<string[]>([])
const dateTypeSaving = ref(false)
const dateTypeDialogOpen = ref(false)
const dateTypeTrigger = ref<HTMLButtonElement | null>(null)
// 「変更」で閉じた時は保存が終わってから、キャンセル・Esc・外側クリックは閉じた直後に、チップへ focus を戻す
// （戻さないとダイアログが消えた後に focus が BODY へ落ち、キーボードの利用者が位置を見失う）
let dateTypeConfirming = false
const dateTypeItems = computed(() =>
  SCHEDULE_DATE_TYPES.map((value) => ({
    value,
    title: t(`settings.schedule.dateTypes.${value}`),
    ...dateTypeAppearance(value),
  })),
)
const dateTypeLabel = (value: string) => t(`settings.schedule.dateTypes.${value}`)
const formatScheduleDate = (value: string) => {
  const [, month, day] = value.slice(0, 10).split('-')
  return `${Number(month)}/${Number(day)}`
}
// 日程の取得前は既存の試合入力画面を表示し、取得後に種類に合わせて切り替える
const isGameDay = computed(
  () => !currentDateType.value || isGameType(currentDateType.value, gameDateTypes.value),
)
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

// 登録・昇降格・負傷・出場停止（登録・離脱の 3 段）を操作できるのは、開いた日が今の範囲の日の時だけ。
// 操作はその日の日付で記録される（asOfDate に開いた日を渡す）。ほかの日は見るだけ
const gameDateKey = computed(() => dateKey(gameData.value.game_date) || undefined)
const registrationOperable = computed(() =>
  isInCurrentRange(gameData.value.game_date, currentRange.value),
)
const registrationNote = computed(() => {
  if (registrationOperable.value || !currentRangeLoaded.value) return ''
  if (currentRange.value === undefined) return t('gameDay.rangeNote.unknown')
  if (currentRange.value === null) return t('gameDay.rangeNote.seasonOver')
  return t('gameDay.rangeNote.outside')
})

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
  offRosterCount: offRosterAppearances.value.length,
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

// 試合前・試合中を同じ日付の記録として区分別に数える。負傷は無い日の方が多く入力を求めない段なので、状態は 'info' 固定。
const absences = ref<PlayerAbsence[] | null>(null)
const todaysAbsences = computed(
  () =>
    absences.value?.filter(
      (a) => a.start_date?.slice(0, 10) === gameData.value.game_date?.slice(0, 10),
    ) ?? null,
)
const absenceSummary = computed(() => {
  // 読み込み前は何も出さない（件数は状態なので残すが、段の説明文は付けない）
  if (!todaysAbsences.value) return ''
  return t('gameDay.summary.absencesByPhase', {
    pre: todaysAbsences.value.filter((a) => a.phase === 'pre_game').length,
    inGame: todaysAbsences.value.filter((a) => a.phase === 'in_game').length,
  })
})

const fetchAbsenceState = async () => {
  if (!gameData.value.season_id) return
  try {
    const response = await axios.get<PlayerAbsence[]>('/player_absences', {
      params: { season_id: gameData.value.season_id },
    })
    absences.value = Array.isArray(response.data) ? response.data : null
  } catch (error) {
    absences.value = null
    console.error('Failed to fetch player absences:', error)
  }
}

const mismatch = computed(() =>
  !isGameDay.value || appearanceCount.value === null
    ? null
    : detectRecordMismatch(savedRecord.value),
)
const mismatchMessage = computed(() => {
  const key = mismatchMessageKey(mismatch.value)
  return key ? t(key) : ''
})

const rosterWarningMessage = computed(() => {
  if (!isGameDay.value || offRosterAppearances.value.length === 0) return ''
  const names = offRosterAppearances.value
    .map((a) =>
      t('gameDay.rosterWarning.pitcher', {
        name: a.name,
        status: t(`gameDay.rosterWarning.status.${a.status}`),
      }),
    )
    .join(t('gameDay.rosterWarning.separator'))
  return t('gameDay.rosterWarning.message', { names })
})

// ─────────────────────────────────────────
// 表示用の文
// ─────────────────────────────────────────

// 上の段の 1 行。得点・予告先発だけでなく相手・ホーム/ビジター・DH も保存済みの値で出す（入力途中の値で揺れない）
const gameDayHead = computed(() =>
  buildGameDayHead({
    opponentName: savedHeadNames.value.opponentShortName,
    score: savedFields.value.score,
    opponentScore: savedFields.value.opponentScore,
    noGame: savedFields.value.noGame,
    homeAway: savedFields.value.homeAway,
    designatedHitter: savedFields.value.designatedHitter,
    starterName: savedHeadNames.value.starterName,
  }),
)

const pitcherSummary = computed(() =>
  appearanceCount.value ? t('gameDay.summary.pitcherCount', { count: appearanceCount.value }) : '',
)

// ─────────────────────────────────────────
// ステップ（PC 幅 = ステッパー + タブ、スマホ幅 = 縦積みの折りたたみ）
// どちらの形も、同じ steps・同じ状態から描く（判定は上の computed と gameDayStatus.ts）
// ─────────────────────────────────────────

// md 以上（960px〜）はステッパー。狭い幅は縦積み。
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
      summary: absenceSummary.value,
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
      // 投手状態は、試合前に確かめる状態なので登録・離脱の最後に置く。入力を求めない段（info）で、
      // 見るだけなので登録・離脱の操作範囲（registrationOperable）には従わず、どの日でも出す
      id: 'pitcherStatus',
      slug: 'pitcher-status',
      group: 'registration',
      no: 4,
      icon: 'mdi-clipboard-pulse-outline',
      title: t('gameDay.sections.pitcherStatus'),
      state: 'info',
      hasBody: true,
      lazy: true,
    },
    {
      id: 'setup',
      slug: 'setup',
      group: 'game',
      no: 5,
      icon: 'mdi-clipboard-list-outline',
      title: t('gameDay.sections.setup'),
      state: setupState.value,
      hasBody: true,
    },
    {
      id: 'result',
      slug: 'result',
      group: 'game',
      no: 6,
      icon: 'mdi-scoreboard-outline',
      title: t('gameDay.sections.result'),
      state: resultState.value,
      hasBody: true,
    },
    {
      id: 'pitchers',
      slug: 'pitchers',
      group: 'game',
      no: 7,
      icon: 'mdi-baseball',
      title: t('gameDay.sections.pitchers'),
      summary: pitcherSummary.value,
      state: pitcherState.value,
      hasBody: true,
      lazy: true,
    },
  ]
  // 登録・離脱の 3 段は試合の無い日にも出す。投手状態は試合日の段なので試合の無い日には出さない
  return allSteps.filter(
    (step) => isGameDay.value || (step.group === 'registration' && step.id !== 'pitcherStatus'),
  )
})
const progressSteps = computed(() =>
  steps.value.filter((step) => ['setup', 'result', 'pitchers'].includes(step.id)),
)

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
})

// 開くたびに離脱一覧を再取得する。
const embedKey = reactive({ absences: 0 })
const refreshEmbedded = (id: string) => {
  if (id === 'absences') {
    embedKey.absences += 1
    fetchAbsenceState()
  }
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
  absences: ['absences'],
  'in-game-absences': ['absences'],
}

const stateOf = (id: string) => steps.value.find((s) => s.id === id)?.state

// 候補の中で、要確認（赤）を先に、次に最初の未入力・編集中のステップ。無ければ undefined
const attentionStep = (candidates: string[]): string | undefined =>
  candidates.find((id) => stateOf(id) === 'warn') ??
  candidates.find((id) => stateOf(id) === 'todo' || stateOf(id) === 'editing')

// 旧タブ名が指すステップ。overview は 予告先発・対戦設定 と 結果 のうち、手の要る方（無ければ結果）
const stepForTab = (tab: string): string =>
  tab === 'absences' || tab === 'in-game-absences'
    ? 'absences'
    : tab === 'pitchers'
      ? 'pitchers'
      : tab === 'pitcher_status'
        ? 'pitcherStatus'
        : (attentionStep(['setup', 'result']) ?? 'result')

const scrollToSection = (id: string) => {
  nextTick(() => {
    const slug = steps.value.find((s) => s.id === id)?.slug ?? id
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
      savedHeadNames.value = {
        opponentShortName: gameData.value.opponent_team_short_name ?? '',
        starterName: gameData.value.announced_starter_name ?? '',
      }
    }
  } catch (error) {
    console.error('Failed to fetch season data:', error)
  }
}

const fetchAppearanceCount = async () => {
  if (!gameData.value.team_id || !gameData.value.game_date) return
  try {
    const response = await axios.get<PitcherAppearanceRecord[]>('/pitcher_appearances', {
      params: { team_id: gameData.value.team_id, schedule_date: gameData.value.game_date },
    })
    const rows = Array.isArray(response?.data) ? response.data : null
    appearanceCount.value = rows ? rows.length : null
    offRosterAppearances.value = (rows ?? [])
      .filter((a) => isOffRoster(a.roster_status))
      .map((a) => ({
        name: a.pitcher_name ?? `ID ${a.pitcher_id}`,
        status: a.roster_status as string,
      }))
  } catch (error) {
    appearanceCount.value = null
    offRosterAppearances.value = []
    console.error('Failed to fetch pitcher appearances:', error)
  }
}

const fetchSeasonInfo = async () => {
  try {
    const response = await axios.get(`/teams/${teamId.value}/season`)
    seasonCurrentDate.value = response?.data?.current_date ?? null
    currentRange.value = response?.data?.current_range ?? null
    gameDateTypes.value = response?.data?.game_date_types ?? []
    seasonSchedules.value = (response?.data?.season_schedules ?? []).map(
      (schedule: SeasonScheduleLite) => ({ ...schedule }),
    )
    currentDateType.value =
      seasonSchedules.value.find((s) => String(s.id) === String(scheduleId.value))?.date_type ?? ''
  } catch (error) {
    seasonCurrentDate.value = null
    currentRange.value = undefined
    seasonSchedules.value = []
    // currentDateType は消さない。日付種類を変更した直後の再取得が失敗しても、変更で確定した種類（または
    // 読み込み済みの種類）を表示に残す。範囲は取得できなかった扱い（読み取り専用）に倒す。
    // 画面を開き直す時の初期化は loadAll が行う
    console.error('Failed to fetch season info:', error)
  } finally {
    currentRangeLoaded.value = true
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
  currentRangeLoaded.value = false
  currentDateType.value = ''
  appearanceCount.value = null
  offRosterAppearances.value = []
  absences.value = null
  pitcherDirty.value = false
  await fetchGame()
  await Promise.all([fetchAppearanceCount(), fetchSeasonInfo(), fetchAbsenceState()])
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

const restoreDateTypeFocus = async () => {
  await nextTick()
  const trigger = dateTypeTrigger.value
  if (!trigger || trigger.disabled) return
  // 利用者が別の場所へ focus を移していたら奪わない（BODY か、消えつつあるダイアログの中だけを戻す）
  const active = document.activeElement
  if (active && active !== document.body && !active.closest('.v-overlay')) return
  trigger.focus({ preventScroll: true })
}

watch(dateTypeDialogOpen, async (open) => {
  if (open) return
  await nextTick()
  if (!dateTypeConfirming) await restoreDateTypeFocus()
})

const onDateTypeConfirm = async (nextType: string) => {
  dateTypeConfirming = true
  try {
    await updateDateType(nextType)
  } finally {
    dateTypeConfirming = false
    await restoreDateTypeFocus()
  }
}

const updateDateType = async (nextType: string) => {
  const previous = currentDateType.value
  if (!previous || nextType === previous || hasUnsavedChanges.value || dateTypeSaving.value) return
  if (!SCHEDULE_DATE_TYPES.some((type) => type === nextType)) return
  if (
    isGameType(previous, gameDateTypes.value) &&
    !isGameType(nextType, gameDateTypes.value) &&
    hasSavedGameData.value
  ) {
    const accepted = await confirmDialog.value?.open(
      t('gameDay.dateType.confirmTitle'),
      t('gameDay.dateType.confirmMessage'),
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
    // 日程の種類が変わると試合日の集合が変わり、今の範囲が動く。取り直さないと登録・離脱の操作可否が古いまま残る
    await fetchSeasonInfo()
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
    const previousStarter = savedFields.value.announcedStarterId
    const previousStarterName = savedHeadNames.value.starterName
    const response = await axios.put(`/game/${scheduleId.value}`, gameData.value)
    takeBaseline()
    // 保存した相手・予告先発の名前は、サーバの応答から取る。応答に無い時（古いサーバ）は、相手はチーム一覧から引き、
    // 予告先発は選び直していなければ前の名前を残し、選び直していれば名前が分からないので出さない
    const savedOpponent = allTeams.value.find(
      (team) => team.id === savedFields.value.opponentTeamId,
    )
    savedHeadNames.value = {
      opponentShortName:
        response?.data?.opponent_team_short_name ??
        (savedOpponent ? savedOpponent.short_name || savedOpponent.name : ''),
      starterName:
        response?.data?.announced_starter_name ??
        (savedFields.value.announcedStarterId === previousStarter ? previousStarterName : ''),
    }
    // 得点・ノーゲームの保存でサーバが登板記録の区分を作り直す。登板記録タブを開いていれば保存済みの区分を取り直す
    await pitcherTabRef.value?.refreshSavedResultCategories?.()
    // 結果の保存で「今の範囲」が進む。取り直さないと、範囲を出た登録・昇降格・負傷・出場停止の 3 段が操作可能のまま残る
    await fetchSeasonInfo()
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

// ヘッダーバー: タイトル=チーム名、サブタイトル=「Game N ・ 日付」（試合日以外は日付のみ）、戻り先=シーズン
// チーム名が届くまでは宣言せず、route.meta.title をバーに出す
useAppBarTitle(() =>
  gameData.value.team_name
    ? {
        title: gameData.value.team_name,
        subtitle: isGameDay.value
          ? `Game ${gameData.value.game_number} ・ ${formattedGameDate.value}`
          : formattedGameDate.value,
        back: { to: seasonPortalRoute.value, label: t('seasonPortal.shortTitle') },
      }
    : null,
)

// ─────────────────────────────────────────
// 離脱ガード・試合日の移動
// ─────────────────────────────────────────

// 未保存の入力がある時、離れる前に確認する（ブラウザのタブを閉じる・再読み込みは beforeunload）
const confirmDiscard = async (): Promise<boolean> => {
  if (!hasUnsavedChanges.value) return true
  const ok = await confirmDialog.value?.open(
    t('gameDay.leaveConfirm.title'),
    t('gameDay.leaveConfirm.message'),
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
})
</script>

<style scoped>
.game-log-textarea :deep(textarea) {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, 'Courier New', monospace;
  font-size: 0.85rem;
  line-height: 1.4;
}
.date-type-trigger {
  display: inline-flex;
  align-items: center;
  min-height: 32px;
  padding: 0;
  border: 0;
  border-radius: 16px;
  background: none;
  color: inherit;
  font: inherit;
  cursor: pointer;
}
.date-type-trigger:focus-visible {
  outline: 2px solid rgb(var(--v-theme-link));
  outline-offset: 2px;
}
.date-type-trigger:disabled {
  cursor: default;
  opacity: 0.6;
}
.date-type-trigger :deep(.v-chip) {
  cursor: inherit;
}
/* スマホ幅でも押しやすい大きさ（44px 四方） */
@media (max-width: 599.98px) {
  .date-type-trigger {
    min-width: 44px;
    min-height: 44px;
  }
}
.game-day-progress {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
.game-day-progress__pills {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.game-day-progress__pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 2px 8px 2px 2px;
  border: 1px solid rgb(var(--v-theme-border-strong));
  border-radius: 20px;
  font-size: 0.75rem;
  font-weight: 600;
  white-space: nowrap;
}
/* 上の段の 1 行（もっく案1＋予告先発）。日付の下に 1 行ぶん全幅で置く。親の行間（16px）の半分だけ日付に寄せる */
.game-day-headline {
  flex: 0 0 100%;
  min-width: 0;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px 12px;
  margin-top: -8px;
}
.game-day-headline__vs,
.game-day-headline__score {
  font-size: 1.375rem;
  font-weight: 700;
  line-height: 1.4;
}
.game-day-headline__vs {
  min-width: 0;
  letter-spacing: 0.02em;
  overflow-wrap: anywhere;
}
.game-day-headline__vs small {
  margin-right: 4px;
  font-size: 0.875rem;
  font-weight: 600;
  color: rgb(var(--v-theme-on-surface-variant));
}
.game-day-headline__score {
  font-variant-numeric: tabular-nums;
}
/* 勝敗の札。色だけで伝えないため文字（勝・負・分・ノーゲーム）を付ける。配色はシーズン画面の勝敗の印と同じ */
.game-day-headline__result {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 28px;
  height: 26px;
  padding: 0 6px;
  border-radius: 6px;
  font-size: 0.875rem;
  font-weight: 700;
  white-space: nowrap;
}
.game-day-headline__result--win {
  background: rgb(var(--v-theme-result-win));
  color: rgb(var(--v-theme-on-result-win));
}
.game-day-headline__result--lose {
  background: rgb(var(--v-theme-result-loss));
  color: rgb(var(--v-theme-on-result-loss));
}
.game-day-headline__result--draw {
  background: rgb(var(--v-theme-result-draw));
  color: rgb(var(--v-theme-on-result-draw));
}
/* ノーゲームは勝敗の色を付けず、枠だけの札にする */
.game-day-headline__result--no_game {
  border: 1px solid rgb(var(--v-theme-on-result-nogame));
  color: rgb(var(--v-theme-on-result-nogame));
}
.game-day-headline__tag {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 1px 8px;
  border: 1px solid rgb(var(--v-theme-border-strong));
  border-radius: 999px;
  font-size: 0.75rem;
  white-space: nowrap;
}
.game-day-headline__starter {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  min-width: 0;
  font-size: 0.8125rem;
  overflow-wrap: anywhere;
}
.game-day-mismatch {
  border: 1px solid rgb(var(--v-theme-on-state-warn));
}
.game-day-mismatch__button {
  border-color: rgb(var(--v-theme-on-state-warn));
  color: rgb(var(--v-theme-on-state-warn));
}
.game-day-secondary :deep(.v-btn__content) {
  color: rgb(var(--v-theme-on-surface));
}
.game-day-secondary {
  border-color: rgb(var(--v-theme-border-strong));
}
</style>
