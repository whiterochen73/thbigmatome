<!-- eslint-disable vue/valid-v-slot -->
<template>
  <div class="overview" data-testid="dashboard-overview">
    <!-- 要約タイル。タイルごとに自分の API の読み込み中・失敗を持つ（遅い API が他を待たせない） -->
    <div class="overview__tiles">
      <div v-for="t in tiles" :key="t.id" class="overview-tile" :data-testid="`tile-${t.id}`">
        <div class="overview-tile__top">
          <span class="overview-tile__icon" :class="`bg-${t.color}`">
            <v-icon :icon="t.icon" size="20" />
          </span>
          <span class="overview-tile__label">{{ t.label }}</span>
          <v-btn
            class="overview-tile__go"
            icon="mdi-chevron-right"
            variant="text"
            size="small"
            density="comfortable"
            :aria-label="`${t.label}の明細を開く`"
            @click="emit('navigate', t.tab)"
          />
        </div>
        <AsyncState
          :loading="t.resource.loading"
          :empty="t.resource.loading"
          :error="t.resource.failed"
          :error-message="t.errorMessage"
          skeleton="heading"
          @retry="emit('retry', t.key)"
        >
          <template v-if="!t.resource.failed">
            <div class="overview-tile__value">
              {{ t.value }}<small>{{ t.unit }}</small>
            </div>
            <div class="overview-tile__sub">{{ t.sub }}</div>
          </template>
        </AsyncState>
      </div>
    </div>

    <!-- 注意が要るもの -->
    <v-card class="overview__attention">
      <div class="overview-card-head">
        <v-icon icon="mdi-alert-circle-outline" size="22" class="on-surface-variant" />
        <h3>注意が要るもの</h3>
      </div>

      <div class="attention-group" data-testid="attention-violation">
        <div class="attention-group__head">
          <v-chip
            :color="CHECK_COLOR[checkTone]"
            variant="flat"
            size="small"
            :prepend-icon="CHECK_ICON[checkTone]"
          >
            要確認<template v-if="rosterReady"> {{ summary.checkTeams }}</template>
          </v-chip>
        </div>
        <div class="attention-group__body">
          <AsyncState
            :loading="rosterStatus.loading"
            :empty="rosterStatus.loading"
            :error="rosterStatus.failed"
            error-message="1軍登録状況の取得に失敗しました"
            skeleton="list-item"
            @retry="emit('retry', 'rosterStatus')"
          >
            <template v-if="!rosterStatus.failed">
              <div v-if="checkRows.length === 0" class="ok-line">
                <v-icon
                  v-if="costsReady"
                  icon="mdi-check-circle"
                  size="18"
                  class="bg-state-done ok-line__icon"
                />
                <v-icon
                  v-else
                  icon="mdi-minus-circle-outline"
                  size="18"
                  class="on-surface-variant"
                />
                規定違反はありません
              </div>
              <!-- 規定違反のチームが先。合計コストの超過だけのチームは重要度が低いので、後ろに控えめに並べる -->
              <div
                v-for="r in checkRows"
                :key="r.team_id"
                class="attention-row"
                :class="{ 'attention-row--minor': r.warnings.length === 0 }"
                :data-testid="r.warnings.length > 0 ? 'check-row-violation' : 'check-row-cost'"
              >
                <div class="attention-row__name">
                  <TeamNameLink
                    :team-id="r.team_id"
                    :name="r.team_name"
                    @open="emit('open-season', $event)"
                  />
                </div>
                <div class="attention-row__chips">
                  <v-chip
                    v-for="w in r.warnings"
                    :key="w"
                    color="state-warn"
                    variant="flat"
                    size="small"
                    prepend-icon="mdi-alert-circle"
                  >
                    {{ w }}
                  </v-chip>
                  <v-chip
                    v-if="r.overBy !== null"
                    color="state-neutral"
                    variant="flat"
                    size="small"
                    prepend-icon="mdi-alert-outline"
                  >
                    合計コスト超過 {{ r.overBy }}
                  </v-chip>
                </div>
              </div>
              <!-- コストが取れていない間は、合計コスト超過の有無が分からない。「問題なし」に見せない -->
              <div v-if="!costsReady" class="ok-line" data-testid="check-cost-pending">
                <v-icon icon="mdi-minus-circle-outline" size="18" class="on-surface-variant" />
                {{
                  costs.failed
                    ? '合計コストの超過は確認できていません（取得に失敗）'
                    : '合計コストの超過は確認中です'
                }}
              </div>
            </template>
          </AsyncState>
        </div>
      </div>

      <div class="attention-group" data-testid="attention-cost">
        <div class="attention-group__head">
          <v-chip
            :color="
              !costsReady
                ? 'state-neutral'
                : summary.costWatchTeams > 0
                  ? 'state-todo'
                  : 'state-done'
            "
            variant="flat"
            size="small"
            :prepend-icon="
              !costsReady
                ? undefined
                : summary.costWatchTeams > 0
                  ? 'mdi-alert'
                  : 'mdi-check-circle'
            "
          >
            チーム上限<template v-if="costsReady"> {{ summary.costWatchTeams }}</template>
          </v-chip>
        </div>
        <div class="attention-group__body">
          <AsyncState
            :loading="costs.loading"
            :empty="costs.loading"
            :error="costs.failed"
            error-message="コスト使用状況の取得に失敗しました"
            skeleton="list-item"
            @retry="emit('retry', 'costs')"
          >
            <template v-if="!costs.failed">
              <div v-if="costWatchRows.length === 0" class="ok-line">
                <v-icon icon="mdi-check-circle" size="18" class="bg-state-done ok-line__icon" />
                なし
              </div>
              <div v-for="c in costWatchRows" :key="c.team_id" class="attention-row">
                <div class="attention-row__name">
                  <TeamNameLink
                    :team-id="c.team_id"
                    :name="c.team_name"
                    @open="emit('open-season', $event)"
                  />
                </div>
                <div class="attention-row__meter">
                  <v-progress-linear
                    :model-value="Math.min((c.total_cost / c.total_cost_limit) * 100, 100)"
                    :color="costBarColor(costLevel(c.total_cost, c.total_cost_limit))"
                    bg-color="surface-variant"
                    bg-opacity="1"
                    height="8"
                    rounded
                  />
                </div>
                <div class="attention-row__figure">
                  <b>{{ c.total_cost }}</b> / {{ c.total_cost_limit }}
                  <v-chip
                    v-if="c.total_cost > c.total_cost_limit"
                    color="state-warn"
                    variant="flat"
                    size="small"
                    prepend-icon="mdi-alert-circle"
                  >
                    超過 {{ c.total_cost - c.total_cost_limit }}
                  </v-chip>
                  <v-chip
                    v-else
                    color="state-todo"
                    variant="flat"
                    size="small"
                    prepend-icon="mdi-alert"
                  >
                    残り {{ c.total_cost_limit - c.total_cost }}
                  </v-chip>
                </div>
              </div>
            </template>
          </AsyncState>
        </div>
      </div>

      <div class="attention-group" data-testid="attention-soon">
        <div class="attention-group__head">
          <v-chip
            color="state-info"
            variant="flat"
            size="small"
            prepend-icon="mdi-clock-check-outline"
          >
            復帰間近<template v-if="soonReady">
              {{ summary.absenceSoon + summary.cooldownSoon }}</template
            >
          </v-chip>
        </div>
        <div class="attention-group__body">
          <div data-testid="attention-soon-absence">
            <AsyncState
              :loading="absences.loading"
              :empty="absences.loading"
              :error="absences.failed"
              error-message="離脱者の取得に失敗しました"
              skeleton="list-item"
              @retry="emit('retry', 'absences')"
            >
              <template v-if="!absences.failed">
                <div v-if="soonAbsences.length === 0" class="ok-line">
                  <v-icon icon="mdi-minus-circle-outline" size="18" class="on-surface-variant" />
                  2日以内に復帰する人はいません
                </div>
                <div v-for="a in soonAbsences" :key="a.id" class="attention-row">
                  <div class="attention-row__name">
                    <TeamNameLink
                      :team-id="a.team_id"
                      :name="a.team_name"
                      @open="emit('open-season', $event)"
                    />
                  </div>
                  <div class="attention-row__mid">
                    {{ a.player_name }}
                    <StatusChip
                      :status="a.absence_type"
                      :label="absenceTypeLabels[a.absence_type] ?? a.absence_type"
                      size="small"
                      class="ml-1"
                    />
                  </div>
                  <div class="attention-row__figure">
                    <v-chip
                      color="state-done"
                      variant="flat"
                      size="small"
                      prepend-icon="mdi-clock-check-outline"
                    >
                      あと {{ remainingLabel(a) }}
                    </v-chip>
                  </div>
                </div>
              </template>
            </AsyncState>
          </div>
          <div data-testid="attention-soon-cooldown">
            <AsyncState
              :loading="cooldowns.loading"
              :empty="cooldowns.loading"
              :error="cooldowns.failed"
              error-message="クールダウン中の選手の取得に失敗しました"
              skeleton="list-item"
              @retry="emit('retry', 'cooldowns')"
            >
              <div v-if="!cooldowns.failed" class="attention-row">
                <div class="attention-row__name">クールダウンが明ける人</div>
                <div class="attention-row__mid text-caption on-surface-variant">
                  {{ summary.cooldownSoon }} 人
                </div>
                <div class="attention-row__figure">
                  <v-btn
                    variant="outlined"
                    size="small"
                    class="overview-link-btn"
                    prepend-icon="mdi-timer-sand"
                    @click="emit('navigate', 'cooldowns')"
                  >
                    一覧へ
                  </v-btn>
                </div>
              </div>
            </AsyncState>
          </div>
        </div>
      </div>
    </v-card>

    <!-- チームの進み具合 -->
    <div data-testid="team-table-section">
      <AsyncState
        framed
        :loading="teams.loading"
        :empty="teams.loading || rows.length === 0"
        :error="teams.failed"
        error-message="チーム一覧の取得に失敗しました"
        empty-icon="mdi-account-group-outline"
        empty-message="稼働中のチームがありません"
        @retry="emit('retry', 'teams')"
      >
        <v-card data-testid="team-table-card">
          <div class="overview-card-head">
            <v-icon icon="mdi-baseball-diamond" size="22" class="on-surface-variant" />
            <h3>チームの進み具合</h3>
            <v-chip color="zone-game" variant="flat" size="small">{{ rows.length }} チーム</v-chip>
          </div>
          <!-- 試合数だけが取れない時。他の列は出したまま、この API だけ再読み込みできる -->
          <AsyncState
            v-if="gameProgress.failed"
            error
            error-message="試合数の取得に失敗しました"
            class="game-progress-error"
            data-testid="game-progress-error"
            @retry="emit('retry', 'gameProgress')"
          />
          <v-data-table
            v-model:sort-by="sortBy"
            class="ui-table ui-table--rows"
            mobile-breakpoint="sm"
            :headers="headers"
            :items="rows"
            item-value="id"
            density="compact"
            :items-per-page="-1"
            hide-default-footer
          >
            <template #[`item.name`]="{ item }">
              <div class="team-name">
                <b
                  ><TeamNameLink
                    :team-id="item.id"
                    :name="item.name"
                    @open="emit('open-season', $event)"
                /></b>
                <span v-if="item.manager" class="text-caption on-surface-variant">
                  {{ item.manager }}
                </span>
              </div>
            </template>
            <template #[`item.firstCount`]="{ item }">
              <v-skeleton-loader
                v-if="rosterStatus.loading"
                type="text"
                width="64"
                data-testid="cell-loading"
              />
              <span v-else-if="item.firstCount === null" class="on-surface-variant">—</span>
              <span v-else class="num">
                1軍 {{ item.firstCount }}
                <span class="attention-group__caption on-surface-variant"
                  >/ 2軍 {{ item.secondCount }}</span
                >
              </span>
            </template>
            <template #[`item.progressKey`]="{ item }">
              <v-skeleton-loader
                v-if="gameProgress.loading"
                type="text"
                width="96"
                data-testid="cell-loading"
              />
              <span v-else-if="!item.games" class="on-surface-variant">—</span>
              <div v-else class="progress-meter">
                <v-progress-linear
                  :model-value="Math.max((item.progressRatio ?? 0) * 100, 3)"
                  color="link"
                  bg-color="surface-variant"
                  bg-opacity="1"
                  height="8"
                  rounded
                />
                <span class="progress-meter__count num" data-testid="games-count"
                  ><b>{{ item.games.regular_played }}</b> / {{ item.games.regular_total }}</span
                >
                <div
                  v-if="item.games.playoff_played > 0 || item.games.regular_unrescheduled > 0"
                  class="progress-meter__subs"
                >
                  <span
                    v-if="item.games.playoff_played > 0"
                    class="on-surface-variant"
                    data-testid="playoff-played"
                    >プレーオフ {{ item.games.playoff_played }} 試合</span
                  >
                  <span
                    v-if="item.games.regular_unrescheduled > 0"
                    class="on-surface-variant"
                    data-testid="unrescheduled"
                    >未振替 {{ item.games.regular_unrescheduled }}</span
                  >
                </div>
              </div>
            </template>
            <template #[`item.firstCost`]="{ item }">
              <v-skeleton-loader
                v-if="rosterStatus.loading"
                type="text"
                width="64"
                data-testid="cell-loading"
              />
              <span v-else-if="item.firstCost === null" class="on-surface-variant">—</span>
              <span v-else class="num d-inline-flex align-center ga-1">
                <LimitMark
                  :state="costLimitState(item.firstCost, item.firstCostLimit)"
                  :size="16"
                />
                {{ item.firstCost }} / {{ item.firstCostLimit ?? '—' }}
              </span>
            </template>
            <template #[`item.totalCost`]="{ item }">
              <v-skeleton-loader
                v-if="costs.loading"
                type="text"
                width="96"
                data-testid="cell-loading"
              />
              <span v-else-if="item.totalCost === null" class="on-surface-variant">—</span>
              <div v-else class="total-meter">
                <v-progress-linear
                  :model-value="
                    Math.min(((item.totalCost ?? 0) / (item.totalCostLimit || 1)) * 100, 100)
                  "
                  :color="costBarColor(item.costLevel)"
                  bg-color="surface-variant"
                  bg-opacity="1"
                  height="8"
                  rounded
                />
                <span class="total-meter__figure num"
                  >{{ item.totalCost }}/{{ item.totalCostLimit }}</span
                >
              </div>
            </template>
            <template #[`item.attention`]="{ item }">
              <div class="attention-chips">
                <v-chip
                  v-if="item.warnings.length > 0"
                  color="state-warn"
                  variant="flat"
                  size="small"
                  prepend-icon="mdi-alert-circle"
                >
                  要確認
                </v-chip>
                <v-chip
                  v-if="item.costLevel === 'over'"
                  color="state-warn"
                  variant="flat"
                  size="small"
                  prepend-icon="mdi-alert-circle"
                >
                  超過
                </v-chip>
                <v-chip
                  v-else-if="item.costLevel === 'near'"
                  color="state-todo"
                  variant="flat"
                  size="small"
                  prepend-icon="mdi-alert"
                >
                  上限に近い
                </v-chip>
                <v-chip
                  v-if="item.absenceCount > 0"
                  :color="ABSENCE_APPEARANCE.injury!.color"
                  variant="flat"
                  size="small"
                  :prepend-icon="ABSENCE_APPEARANCE.injury!.icon"
                >
                  離脱 {{ item.absenceCount }}
                </v-chip>
                <v-chip
                  v-if="item.cooldownCount > 0"
                  :color="ABSENCE_APPEARANCE.cooldown!.color"
                  variant="flat"
                  size="small"
                  :prepend-icon="ABSENCE_APPEARANCE.cooldown!.icon"
                >
                  クールダウン {{ item.cooldownCount }}
                </v-chip>
                <span v-if="item.attention === 0" class="attention-none on-surface-variant">—</span>
              </div>
            </template>
            <template #[`item.actions`]="{ item }">
              <RowIconButton
                icon="mdi-calendar-star"
                :label="`${item.name}のシーズン`"
                @click="emit('open-season', { id: item.id, name: item.name })"
              />
            </template>
          </v-data-table>
          <div class="inactive-note on-surface-variant" data-testid="inactive-note">
            <v-icon icon="mdi-account-group-outline" size="20" />
            休止中のチーム {{ summary.inactiveTeams }} 件
          </div>
        </v-card>
      </AsyncState>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import AsyncState from '@/components/shared/AsyncState.vue'
import LimitMark from '@/components/shared/LimitMark.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'
import { costLimitState } from '@/components/shared/rosterLimits'
import StatusChip from '@/components/shared/StatusChip.vue'
import TeamNameLink from '@/components/shared/TeamNameLink.vue'
import { tableCell } from '@/components/shared/tableCells'
import { ABSENCE_APPEARANCE } from '@/components/gameDay/gameDayStatus'
import {
  type DashboardResourceKey,
  type DashboardSummary,
  type DashboardTab,
  buildCheckRows,
  buildTeamRows,
  checkState,
  CHECK_COLOR,
  costBarColor,
  costLevel,
  isImminent,
  remainingCount,
  summarize,
} from '@/components/commissioner/dashboardLogic'
import type {
  AbsenceRecord,
  CooldownRecord,
  CostRecord,
  DashboardResource,
  GameProgressRecord,
  RosterStatusRecord,
} from '@/types/commissionerDashboard'
import type { Team } from '@/types/team'

// 概況: 要約タイル → 注意が要るもの → チームの進み具合（1 チーム 1 行）。
// API は 6 本ぶん別々の状態で受け取り、team_id で結合して数える。
const props = defineProps<{
  teams: DashboardResource<Team>
  absences: DashboardResource<AbsenceRecord>
  cooldowns: DashboardResource<CooldownRecord>
  costs: DashboardResource<CostRecord>
  rosterStatus: DashboardResource<RosterStatusRecord>
  gameProgress: DashboardResource<GameProgressRecord>
}>()

const emit = defineEmits<{
  navigate: [tab: DashboardTab]
  retry: [key: DashboardResourceKey]
  'open-season': [team: { id: number; name: string }]
}>()

const sources = computed(() => ({
  teams: props.teams.data,
  absences: props.absences.data,
  cooldowns: props.cooldowns.data,
  costs: props.costs.data,
  rosterStatus: props.rosterStatus.data,
}))
const summary = computed(() => summarize(sources.value))
const rows = computed(() =>
  buildTeamRows({ ...sources.value, gameProgress: props.gameProgress.data }),
)

const ready = (r: DashboardResource<unknown>) => !r.loading && !r.failed
const rosterReady = computed(() => ready(props.rosterStatus))
const costsReady = computed(() => ready(props.costs))
const soonReady = computed(() => ready(props.absences) && ready(props.cooldowns))

const absenceTypeLabels: Record<string, string> = {
  injury: '負傷',
  suspension: '出場停止',
  reconditioning: 'リコンディショニング',
}

const checkRows = computed(() => buildCheckRows(props.rosterStatus.data, props.costs.data))
const checkTone = computed(() =>
  checkState(summary.value.checkTeams, rosterReady.value, costsReady.value),
)
const CHECK_ICON = {
  warn: 'mdi-alert-circle',
  done: 'mdi-check-circle',
  neutral: undefined,
} as const
const costWatchRows = computed(() =>
  props.costs.data
    .filter((c) => costLevel(c.total_cost, c.total_cost_limit) !== 'normal')
    .sort((a, b) => b.total_cost - a.total_cost),
)
const soonAbsences = computed(() =>
  props.absences.data.filter((a) => isImminent(remainingCount(a))),
)
const remainingLabel = (a: AbsenceRecord) =>
  `${remainingCount(a)}${a.duration_unit === 'days' ? '日' : '試合'}`

// 要確認タイルの補足。内訳（規定違反・合計コスト超過）。コストが取れていない間は、超過の有無が不明だと伝える
const checkSub = (s: DashboardSummary) => {
  if (!costsReady.value) {
    const note = props.costs.failed ? 'コストを取得できません' : 'コストを確認中'
    return s.checkTeams > 0 ? `規定違反 ${s.violationTeams} ・ ${note}` : note
  }
  if (s.checkTeams === 0) return '規定内'
  return s.costOverTeams > 0
    ? `規定違反 ${s.violationTeams} ・ 合計コスト超過 ${s.costOverTeams}`
    : '規定を外れたチーム'
}

const tiles = computed(() => {
  const s = summary.value
  return [
    {
      id: 'active',
      key: 'teams' as const,
      tab: 'teams' as const,
      resource: props.teams,
      errorMessage: 'チーム一覧の取得に失敗しました',
      label: '稼働中のチーム',
      icon: 'mdi-account-group',
      color: 'zone-game',
      value: s.activeTeams,
      unit: ` / ${s.totalTeams}`,
      sub: `休止中 ${s.inactiveTeams} チーム`,
    },
    {
      id: 'violation',
      key: 'rosterStatus' as const,
      tab: 'rosterStatus' as const,
      resource: props.rosterStatus,
      errorMessage: '1軍登録状況の取得に失敗しました',
      label: '要確認',
      icon:
        checkTone.value === 'neutral' ? 'mdi-clipboard-list-outline' : CHECK_ICON[checkTone.value],
      color: CHECK_COLOR[checkTone.value],
      value: s.checkTeams,
      unit: ' チーム',
      sub: checkSub(s),
    },
    {
      id: 'absence',
      key: 'absences' as const,
      tab: 'absences' as const,
      resource: props.absences,
      errorMessage: '離脱者の取得に失敗しました',
      label: '離脱中',
      icon: 'mdi-hospital-box',
      color: 'absence-out',
      value: s.absenceCount,
      unit: ' 人',
      sub: `${s.absenceTeams} チーム ・ 2日以内に復帰 ${s.absenceSoon} 人`,
    },
    {
      id: 'cooldown',
      key: 'cooldowns' as const,
      tab: 'cooldowns' as const,
      resource: props.cooldowns,
      errorMessage: 'クールダウン中の選手の取得に失敗しました',
      label: 'クールダウン中',
      icon: 'mdi-timer-sand',
      color: 'absence-cooldown',
      value: s.cooldownCount,
      unit: ' 人',
      sub: `${s.cooldownTeams} チーム ・ 2日以内に明ける ${s.cooldownSoon} 人`,
    },
    {
      id: 'cost',
      key: 'costs' as const,
      tab: 'costs' as const,
      resource: props.costs,
      errorMessage: 'コスト使用状況の取得に失敗しました',
      label: 'コスト上限に近い',
      icon: 'mdi-currency-jpy',
      color: !costsReady.value
        ? 'state-neutral'
        : s.costWatchTeams > 0
          ? 'state-todo'
          : 'state-done',
      value: s.costWatchTeams,
      unit: ' チーム',
      sub: '合計コストが上限の 95% 以上',
    },
  ]
})

const sortBy = ref([{ key: 'progressKey', order: 'asc' as const }])

// PC は 1 行 7 列。スマホ（<600px）は縦積み（名前=title・1軍=sub1・合計コスト=sub2・進み具合=note・注意=note2・操作=act）。
// 1軍コストはスマホでは出さない（class の無い列）。
const headers = [
  { title: 'チーム ・ 監督', key: 'name', minWidth: 170, cellProps: tableCell.title },
  { title: '1軍', key: 'firstCount', nowrap: true, cellProps: tableCell.sub1 },
  {
    title: '進み具合',
    key: 'progressKey',
    cellProps: { class: `${tableCell.noteLabeled.class} progress-cell` },
  },
  { title: '1軍コスト', key: 'firstCost', nowrap: true, cellProps: { class: 'first-cost-cell' } },
  {
    title: '合計コスト',
    key: 'totalCost',
    nowrap: true,
    cellProps: { class: `${tableCell.sub2.class} total-cost-cell` },
  },
  { title: '注意', key: 'attention', cellProps: tableCell.note2 },
  { title: '', key: 'actions', sortable: false, nowrap: true, cellProps: tableCell.act },
]
</script>

<style scoped>
.overview {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

/* 要約タイル 5 つ。PC は 5 列、スマホは 2 列（最後の 1 つは全幅） */
.overview__tiles {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 12px;
}
@media (max-width: 959.98px) {
  .overview__tiles {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
  .overview-tile:last-child {
    grid-column: 1 / -1;
  }
}
.overview-tile {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
  padding: 12px 14px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  border-radius: 8px;
}
.overview-tile:hover {
  border-color: rgb(var(--v-theme-border-strong));
}
.overview-tile__top {
  display: flex;
  align-items: center;
  gap: 8px;
}
.overview-tile__icon {
  display: inline-flex;
  flex: none;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border-radius: 50%;
}
.overview-tile__label {
  min-width: 0;
  font-size: 0.8125rem;
  font-weight: 700;
  color: rgb(var(--v-theme-on-surface-variant));
}
/* タイル全体を押せるようにする（キーボードはこのボタンに止まる）。再読み込みボタンはその上に出す */
.overview-tile__go {
  margin-inline-start: auto;
  color: rgb(var(--v-theme-on-surface-variant));
}
.overview-tile__go::after {
  content: '';
  position: absolute;
  inset: 0;
}
.overview-tile :deep(.async-state__retry) {
  position: relative;
  z-index: 1;
}
.overview-tile :deep(.v-alert) {
  padding: 8px;
  font-size: 0.75rem;
}
.overview-tile__value {
  margin-top: 4px;
  font-size: 1.75rem;
  font-weight: 700;
  line-height: 1.2;
  font-variant-numeric: tabular-nums;
}
.overview-tile__value small {
  margin-inline-start: 2px;
  font-size: 0.875rem;
  font-weight: 500;
  color: rgb(var(--v-theme-on-surface-variant));
}
.overview-tile__sub {
  font-size: 0.75rem;
  color: rgb(var(--v-theme-on-surface-variant));
}

.overview-card-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  border-bottom: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
}
.overview-card-head h3 {
  margin: 0;
  font-size: 1rem;
  font-weight: 700;
}

/* 注意が要るもの: 左に重さのラベル、右に中身。スマホは縦積み */
.attention-group {
  display: flex;
  gap: 12px;
  align-items: flex-start;
  padding: 12px 16px;
  border-top: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
}
.overview-card-head + .attention-group {
  border-top: 0;
}
.attention-group__head {
  display: flex;
  flex: none;
  flex-direction: column;
  align-items: flex-start;
  gap: 4px;
  width: 150px;
}
.attention-group__caption {
  font-size: 0.75rem;
  line-height: 1.4;
}
.attention-group__body {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}
@media (max-width: 599.98px) {
  .attention-group {
    flex-direction: column;
    gap: 8px;
  }
  .attention-group__head {
    flex-direction: row;
    align-items: center;
    width: auto;
  }
}
.ok-line {
  display: flex;
  align-items: center;
  gap: 8px;
  min-height: 24px;
  font-size: 0.8125rem;
  color: rgb(var(--v-theme-on-surface-variant));
}
.ok-line__icon {
  padding: 2px;
  border-radius: 50%;
}
.attention-row {
  display: grid;
  grid-template-columns: minmax(0, 1.3fr) minmax(0, 1.6fr) auto;
  align-items: center;
  gap: 12px;
  padding: 6px 0;
  border-top: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  font-size: 0.8125rem;
}
.attention-row:first-child {
  border-top: 0;
}
/* 合計コスト超過だけのチーム。規定違反より重要度が低いので、名前を太字にせず、リンクも文字色を落として下線だけにする */
.attention-row--minor .attention-row__name {
  font-weight: 400;
  color: rgb(var(--v-theme-on-surface-variant));
}
.attention-row--minor .attention-row__name .team-name-link {
  color: rgb(var(--v-theme-on-surface-variant));
}
/* 色は本物のリンク（TeamNameLink）だけが持つ。押せない行ラベル（「クールダウンが明ける人」）は普通の文字色。
   省略表示の overflow:hidden が TeamNameLink のフォーカスの輪（2px・offset 2px = 外へ 4px）を切るので、
   内側に 4px の余白を取り、同じだけ負の margin で打ち消して配置は変えない */
.attention-row__name {
  overflow: hidden;
  margin: -4px;
  padding: 4px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.attention-row__chips {
  display: flex;
  flex-wrap: wrap;
  grid-column: 2 / -1;
  gap: 6px;
}
.attention-row__figure {
  display: flex;
  align-items: center;
  gap: 6px;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
@media (max-width: 599.98px) {
  .attention-row {
    grid-template-columns: minmax(0, 1fr) auto;
  }
  .attention-row__mid,
  .attention-row__meter {
    grid-column: 1 / -1;
    order: 3;
  }
  .attention-row__chips {
    grid-column: 1 / -1;
  }
}
.overview-link-btn {
  color: rgb(var(--v-theme-link));
  border-color: rgb(var(--v-theme-border-strong));
}

/* チームの表 */
.team-name {
  display: flex;
  flex-direction: column;
  min-width: 0;
}
.team-name .text-caption {
  font-weight: 400;
}
.team-name b {
  overflow: hidden;
  margin: -4px;
  padding: 4px;
  text-overflow: ellipsis;
}
.progress-meter,
.total-meter {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 110px;
}
.progress-meter {
  flex-wrap: wrap;
  row-gap: 2px;
}
.progress-meter :deep(.v-progress-linear),
.total-meter :deep(.v-progress-linear) {
  flex: 1;
}
.progress-meter :deep(.v-progress-linear) {
  min-width: 56px;
}
.progress-meter__count {
  min-width: 58px;
  text-align: end;
  font-size: 0.75rem;
  white-space: nowrap;
}
/* 未振替・プレーオフは控えめに。棒と数の下の 1 行 */
.progress-meter__subs {
  display: flex;
  flex-basis: 100%;
  flex-wrap: wrap;
  gap: 4px 10px;
  font-size: 0.75rem;
  line-height: 1.3;
}
.game-progress-error {
  padding: 12px 16px 0;
}
.total-meter__figure {
  min-width: 58px;
  text-align: end;
  font-size: 0.75rem;
}
.attention-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.inactive-note {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  border-top: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  font-size: 0.8125rem;
}
.num {
  font-variant-numeric: tabular-nums;
}
</style>
