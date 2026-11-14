<template>
  <!-- 単独の画面として開いた時は骨格（PageLayout）と、バーのタイトル（チーム名）を持つ。
       シーズンのタブ・試合日ページへ埋め込まれた時は中身だけを出し、バーは変えない -->
  <component
    :is="standalone ? PageLayout : 'div'"
    :class="{ 'team-members--embedded': !standalone }"
  >
    <v-alert v-if="!isTeamIdValid" type="info" icon="mdi-account-question">
      チームが選択されていません。ホーム画面でチームを選択してください。
    </v-alert>
    <template v-if="isTeamIdValid">
      <ViolationList :violations="violations" />

      <!-- Player Selection -->
      <div v-if="!readonly" data-testid="add-player-row">
        <!-- ポジションフィルタ（追加候補） -->
        <div class="d-flex flex-wrap ga-2 mb-2 align-center">
          <span class="text-caption text-medium-emphasis"
            >{{ t('teamMembers.addCandidateLabel') }}:</span
          >
          <v-btn
            v-for="f in addPlayerPositionFilters"
            :key="f.value"
            size="x-small"
            :variant="addPlayerPositionFilter === f.value ? 'elevated' : 'outlined'"
            :color="addPlayerPositionFilter === f.value ? 'primary' : undefined"
            rounded
            @click="addPlayerPositionFilter = f.value"
          >
            {{ f.label }}
          </v-btn>
        </div>
        <div class="team-members__add-row">
          <div class="team-members__add-select">
            <v-autocomplete
              v-model="selectedPlayer"
              :items="filteredAvailablePlayers"
              :item-title="(player) => `${player.number} ${player.name}`"
              item-value="id"
              :label="t('teamMembers.selectPlayer')"
              return-object
              clearable
              :disabled="!selectedCostListId"
              :no-data-text="
                !selectedCostListId
                  ? t('teamMembers.loadingCostList')
                  : t('teamMembers.noMatchingPlayers')
              "
              :custom-filter="
                (value, query, item) => {
                  if (!query) return true
                  const q = query.toLowerCase()
                  const raw = item?.raw
                  if (!raw) return false
                  return (
                    raw.name.toLowerCase().includes(q) ||
                    raw.number.toLowerCase().includes(q) ||
                    (raw.short_name ?? '').toLowerCase().includes(q)
                  )
                }
              "
            >
              <template #item="{ props, item }">
                <v-list-item v-bind="props">
                  <template #prepend>
                    <v-chip
                      size="x-small"
                      :color="item.position === 'pitcher' ? 'tag-pitcher' : 'tag-fielder'"
                      variant="flat"
                      :prepend-icon="
                        item.position === 'pitcher' ? 'mdi-baseball' : 'mdi-baseball-bat'
                      "
                      class="mr-2"
                    >
                      {{ item.position ? t(`baseball.positions.${item.position}`) : '—' }}
                    </v-chip>
                  </template>
                  <template #subtitle>
                    {{ getPlayerCostLabel(item) }}
                  </template>
                </v-list-item>
              </template>
            </v-autocomplete>
            <!-- カードバージョン選択（複数バージョンがある場合のみ表示） -->
            <div v-if="cardSetOptions.length > 1" class="mt-1">
              <v-radio-group
                v-model="selectedCardOptionKey"
                inline
                density="compact"
                hide-details
                class="mt-0"
              >
                <v-radio
                  v-for="opt in cardSetOptions"
                  :key="opt.option_key"
                  :value="opt.option_key"
                  class="card-option"
                >
                  <template #label>
                    <v-img
                      v-if="optionImageUrl(opt)"
                      :src="optionImageUrl(opt)!"
                      class="card-option__thumb"
                      width="60"
                      height="82"
                      cover
                    />
                    <span class="card-option__label">{{ opt.label }}</span>
                  </template>
                </v-radio>
              </v-radio-group>
            </div>
          </div>
          <div class="team-members__add-button">
            <v-btn
              :color="gameDayActions ? 'action' : 'link'"
              :variant="gameDayActions ? 'flat' : 'outlined'"
              :prepend-icon="gameDayActions ? 'mdi-plus' : undefined"
              @click="addPlayer"
              :disabled="!selectedPlayer || !selectedCostListId || noRegistrableCard"
              :loading="fetchingCards"
            >
              {{ t('teamMembers.addPlayer') }}
            </v-btn>
          </div>
        </div>
      </div>

      <!-- Team Members Table -->
      <AsyncState
        :loading="loading"
        :error="loadFailed"
        :empty="loadFailed && teamPlayers.length === 0"
        :error-message="t('teamMembers.notifications.fetchTeamPlayersFailed')"
        @retry="reload"
      >
        <v-card variant="outlined">
          <v-card-title class="team-members__title d-flex justify-space-between flex-wrap ga-2">
            <span>{{ t('teamMembers.teamMembersTitle') }}</span>
            <div class="text-subtitle-1">
              <span
                >{{
                  t('teamMembers.totalCount', {
                    count: includedTeamPlayers.length,
                    max: MAX_PLAYERS,
                  })
                }}
                /
              </span>
              <span>{{
                t('teamMembers.totalCost', { cost: totalTeamCost, max: TEAM_TOTAL_MAX_COST })
              }}</span>
            </div>
          </v-card-title>
          <v-card-text>
            <!-- コスト全体ゲージ -->
            <div class="mb-3">
              <div class="d-flex justify-space-between align-center mb-1">
                <div class="d-flex align-center ga-1">
                  <span class="text-body-2 font-weight-medium">{{
                    t('teamMembers.totalCostLabel')
                  }}</span>
                  <v-tooltip location="top" max-width="280">
                    <template #activator="{ props }">
                      <v-icon v-bind="props" size="x-small" class="on-surface-variant"
                        >mdi-help-circle-outline</v-icon
                      >
                    </template>
                    <span>チーム全体のコスト上限は{{ TEAM_TOTAL_MAX_COST }}です。</span>
                  </v-tooltip>
                </div>
                <span
                  class="text-body-2 font-weight-bold"
                  :class="
                    isCostOverLimit
                      ? 'text-error'
                      : costRatio >= 0.85
                        ? 'text-warning'
                        : 'text-success'
                  "
                >
                  {{ totalTeamCost }} / {{ TEAM_TOTAL_MAX_COST }}
                </span>
              </div>
              <v-progress-linear
                :model-value="Math.min(costRatio * 100, 100)"
                height="12"
                rounded
                :color="costGaugeColor"
                bg-color="surface-variant"
              />
              <div class="d-flex justify-space-between mt-1">
                <span class="text-caption text-disabled">0</span>
                <span class="text-caption text-disabled">50</span>
                <span class="text-caption text-disabled">100</span>
                <span class="text-caption text-disabled">150</span>
                <span class="text-caption text-disabled">200</span>
              </div>
            </div>

            <v-alert v-if="isCostOverLimit" type="warning" density="compact" class="mb-2">
              {{
                t('teamMembers.notifications.costLimitExceeded', {
                  cost: totalTeamCost,
                  limit: TEAM_TOTAL_MAX_COST,
                })
              }}
            </v-alert>

            <!-- ポジション内訳バッジ -->
            <div class="d-flex flex-wrap ga-2 mb-3">
              <v-chip
                v-for="(count, position) in positionCounts"
                :key="position"
                size="small"
                variant="tonal"
                color="link"
              >
                {{ t(`baseball.positions.${position}`) }}: {{ count }}
              </v-chip>
            </div>

            <!-- フィルタ -->
            <FilterBar>
              <template #filters>
                <span class="text-caption text-medium-emphasis"
                  >{{ t('teamMembers.positionFilterLabel') }}:</span
                >
                <v-btn
                  v-for="f in positionFilters"
                  :key="f.value"
                  size="x-small"
                  :variant="positionFilter === f.value ? 'elevated' : 'outlined'"
                  :color="positionFilter === f.value ? 'primary' : undefined"
                  rounded
                  @click="positionFilter = f.value"
                >
                  {{ f.label }}
                </v-btn>
              </template>
            </FilterBar>

            <!-- eslint-disable vue/valid-v-slot -->
            <v-data-table
              :headers="headers"
              :items="filteredTeamPlayers"
              :loading="loading"
              :no-data-text="t('teamMembers.noData')"
              density="compact"
              items-per-page="-1"
              :disable-sort="false"
            >
              <template #header.excluded_from_team_total>
                <div class="d-flex align-center ga-1">
                  <span>{{ t('teamMembers.headers.costExcluded') }}</span>
                  <v-tooltip location="top" max-width="240">
                    <template #activator="{ props }">
                      <v-icon v-bind="props" size="x-small" class="on-surface-variant"
                        >mdi-help-circle-outline</v-icon
                      >
                    </template>
                    <span>除外特例を受けた選手をチームの合計コスト計算から除外します。</span>
                  </v-tooltip>
                </div>
              </template>

              <template #no-data>
                <div class="d-flex flex-column align-center py-6">
                  <v-icon size="36" class="mb-2 text-medium-emphasis"
                    >mdi-account-plus-outline</v-icon
                  >
                  <p class="text-medium-emphasis mb-1">選手が登録されていません</p>
                  <p class="text-caption text-disabled">
                    上の選手選択フォームから選手を検索して追加してください
                  </p>
                </div>
              </template>

              <template #item.name="{ item }">
                <PlayerNameLink
                  :player-id="item.id"
                  :player-name="item.name"
                  :player-card-id="item.player_card_id ?? undefined"
                  :cost-type="item.selected_cost_type"
                />
              </template>
              <template #item.display_name="{ item }">
                <v-text-field
                  v-model="item.display_name"
                  :placeholder="t('teamMembers.headers.display_name')"
                  density="compact"
                  hide-details
                  variant="plain"
                  :readonly="readonly"
                />
              </template>
              <template #item.player_type_ids="{ item }">
                <v-chip-group column>
                  <v-chip v-for="typeId in item.player_type_ids" :key="typeId">
                    {{
                      playerTypes.find((pt) => pt.id === typeId)?.name ||
                      t('teamMembers.unknownType')
                    }}
                  </v-chip>
                </v-chip-group>
              </template>
              <template #item.position="{ item }">
                {{ item.position ? t(`baseball.positions.${item.position}`) : '—' }}
              </template>
              <template #item.throws="{ item }">
                {{
                  item.handedness
                    ? t(`baseball.throwingHands.${item.handedness.split('/')[0]}`)
                    : '—'
                }}
              </template>
              <template #item.bats="{ item }">
                {{
                  item.handedness
                    ? t(`baseball.battingHands.${item.handedness.split('/')[1]}`)
                    : '—'
                }}
              </template>
              <template #item.player_card_info="{ item }">
                <div v-if="item.player_card_info" class="d-flex align-center ga-1">
                  <span class="text-caption">{{
                    cardVersionText(item.player_card_info.card_set_name, item.player_card_info)
                  }}</span>
                  <v-chip size="x-small" variant="flat" color="state-neutral">
                    {{ item.player_card_info.card_type }}
                  </v-chip>
                </div>
                <span v-else class="text-caption text-disabled">—</span>
              </template>
              <template #item.cost="{ item }">
                <div class="d-flex align-center">
                  <v-select
                    v-model="item.selected_cost_type"
                    :items="getAvailableCostTypes(item)"
                    item-title="text"
                    item-value="value"
                    density="compact"
                    hide-details
                    :readonly="readonly"
                    @update:modelValue="updatePlayerCost(item)"
                  ></v-select>
                </div>
              </template>
              <template #item.excluded_from_team_total="{ item }">
                <v-checkbox
                  v-model="item.excluded_from_team_total"
                  hide-details
                  density="compact"
                  :disabled="readonly"
                />
              </template>
              <template #item.actions="{ item }">
                <div v-if="!readonly" class="row-actions">
                  <RowIconButton
                    icon="mdi-delete-outline"
                    danger
                    :label="`${item.name}をチームから除外`"
                    @click="removePlayer(item)"
                  />
                </div>
              </template>
            </v-data-table>
          </v-card-text>
        </v-card>
      </AsyncState>

      <!-- Actions -->
      <div v-if="!readonly" class="d-flex justify-end">
        <v-btn
          variant="outlined"
          @click="goBack"
          class="mr-4"
          :style="gameDayActions ? { borderColor: 'rgb(var(--v-theme-border-strong))' } : undefined"
          >{{ t('actions.cancel') }}</v-btn
        >
        <v-btn
          color="action"
          variant="flat"
          :prepend-icon="gameDayActions ? 'mdi-content-save-outline' : undefined"
          @click="saveTeamMembers"
          >{{ t('actions.save') }}</v-btn
        >
      </div>
    </template>
  </component>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import { useAppBarTitle } from '@/composables/useAppBarTitle'
import type { Player } from '@/types/player'
import type { PlayerCost } from '@/types/playerCost'
import type { CostList } from '@/types/costList'
import type { PlayerType } from '@/types/playerType'
import FilterBar from '@/components/shared/FilterBar.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'
import AsyncState from '@/components/shared/AsyncState.vue'
import PageLayout from '@/components/shared/PageLayout.vue'
import PlayerNameLink from '@/components/shared/PlayerNameLink.vue'
import ViolationList from '@/components/season/ViolationList.vue'
import type { RosterViolation } from '@/types/rosterViolation'
import { useColumnMinWidth } from '@/composables/useColumnMinWidth'
import { cardVersionText } from '@/lib/cardVersion'

type CostType =
  | 'normal_cost'
  | 'relief_only_cost'
  | 'pitcher_only_cost'
  | 'fielder_only_cost'
  | 'two_way_cost'

interface PlayerCardInfo {
  id: number
  card_type: string
  card_set_name: string
  card_set_id: number
  variant?: string | null
  version_label?: string | null
  image_url?: string | null
  card_set_current?: boolean
  official_use_prohibited?: boolean
}

interface CardSetOption {
  option_key: string
  card_set_id: number
  card_set_name: string
  variant?: string | null
  label: string
  pitcher_card_id: number | null
  batter_card_id: number | null
  any_card_id: number
}

interface TeamPlayer extends Player {
  selected_cost_type: CostType
  current_cost: number
  excluded_from_team_total: boolean
  display_name?: string | null
  player_type_ids: number[]
  player_card_id?: number | null
  player_card_info?: PlayerCardInfo | null
  available_cost_types?: string[]
}

interface TeamPlayersSaveResponse {
  message?: string
  warnings?: string[]
}

// asOfDate / phase: 読む日付と区分。GET と POST の両方に同じ値を送る。省略時は、シーズンの現在日（GET /teams/:id/season の current_date）と pre_game を両方に送る。
// readonly: 操作できない日（試合日ページで「今の範囲」の外の日）。追加・削除・保存を出さない。
const props = defineProps<{
  teamId?: number
  gameDayActions?: boolean
  asOfDate?: string
  phase?: string
  readonly?: boolean
}>()

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const { showSnackbar } = useSnackbar()

const allPlayers = ref<Player[]>([])
const teamPlayers = ref<TeamPlayer[]>([])
const selectedCost = ref<CostList | null>(null)
const selectedCostListId = computed(() => (selectedCost.value ? selectedCost.value.id : null))
const selectedPlayer = ref<Player | null>(null)
const playerTypes = ref<PlayerType[]>([])
const availablePlayerCards = ref<PlayerCardInfo[]>([])
const selectedCardOptionKey = ref<string | null>(null)
const fetchingCards = ref(false)
// 選手が持つカードの総数（登録できないカードを除く前）。1 枚以上あるのに登録できるカードが 0 枚の選手は追加させない
const playerCardTotal = ref(0)
const noRegistrableCard = computed(
  () => playerCardTotal.value > 0 && availablePlayerCards.value.length === 0,
)

// バリエーション対応コスト検索: variant-specific → base の順にフォールバック
const findCostPlayer = (
  costPlayers: PlayerCost[],
  costId: number | null,
  playerCardId?: number | null,
): PlayerCost | undefined => {
  if (!costId) return undefined
  if (playerCardId != null) {
    const variant = costPlayers.find(
      (cp) => cp.cost_id === costId && cp.player_card_id === playerCardId,
    )
    if (variant) return variant
  }
  return costPlayers.find((cp) => cp.cost_id === costId && cp.player_card_id == null)
}

const cardSetOptions = computed<CardSetOption[]>(() => {
  const map = new Map<string, CardSetOption>()
  for (const card of availablePlayerCards.value) {
    const variant = card.variant?.trim() || null
    const optionKey = `${card.card_set_id}:${variant ?? ''}`
    const existing = map.get(optionKey)
    if (existing) {
      if (card.card_type === 'pitcher') existing.pitcher_card_id = card.id
      else existing.batter_card_id = card.id
    } else {
      map.set(optionKey, {
        option_key: optionKey,
        card_set_id: card.card_set_id,
        card_set_name: card.card_set_name,
        variant,
        label: cardVersionText(card.card_set_name, card),
        pitcher_card_id: card.card_type === 'pitcher' ? card.id : null,
        batter_card_id: card.card_type === 'batter' ? card.id : null,
        any_card_id: card.id,
      })
    }
  }
  return Array.from(map.values())
})

const resolveCardIdFromCardSet = (
  option: CardSetOption,
  position: string | null | undefined,
): number => {
  if (position === 'pitcher') {
    return option.pitcher_card_id ?? option.batter_card_id ?? option.any_card_id
  }
  return option.batter_card_id ?? option.pitcher_card_id ?? option.any_card_id
}

// 選択肢のカードの画像。登録される側（選手の守備位置で決まるカード）の画像を出す。画像が無ければ null（何も出さない）
const optionImageUrl = (option: CardSetOption): string | null => {
  const cardId = resolveCardIdFromCardSet(option, selectedPlayer.value?.position)
  return availablePlayerCards.value.find((c) => c.id === cardId)?.image_url ?? null
}

const teamId = computed(() => props.teamId ?? Number(route.params.teamId))
const isTeamIdValid = computed(() => Number.isFinite(teamId.value) && teamId.value > 0)

// 単独の画面（/teams/:teamId/members）として開いたか。埋め込み（シーズンのタブ・試合日ページ）は teamId を props で受ける
const standalone = computed(() => props.teamId === undefined)

// ヘッダーバー（単独の画面のみ）: タイトル=チーム名、サブタイトル=チーム編成、戻り先=シーズン。
// 埋め込みの時はバーを変えない（宣言しない）。チーム名が届くまでも戻れるよう、単独の間は常に宣言する
const teamName = ref('')
useAppBarTitle(() =>
  standalone.value && isTeamIdValid.value
    ? {
        title: teamName.value || t('seasonPortal.tabs.members'),
        subtitle: teamName.value ? t('seasonPortal.tabs.members') : null,
        back: {
          to: { name: 'SeasonPortal', params: { teamId: teamId.value } },
          label: t('seasonPortal.shortTitle'),
        },
      }
    : null,
)

// 読み込み中は表の空状態（「選手が登録されていません」）を出さない。取得の失敗はページ内のアラート＋再読み込みで出す
const loading = ref(isTeamIdValid.value)
const loadFailed = ref(false)

// Squad limits
const MAX_PLAYERS = 50
const TEAM_TOTAL_MAX_COST = 200

const minW = useColumnMinWidth()
const headers = computed(() => [
  { title: t('teamMembers.headers.number'), key: 'number', minWidth: minW(64) },
  // 横に比べる・入力する表なので縦積みにせず、スマホでは横スクロール。名前の列は左に固定する
  { title: t('teamMembers.headers.name'), key: 'name', fixed: true, minWidth: minW(150) },
  {
    title: t('teamMembers.headers.display_name'),
    key: 'display_name',
    sortable: false,
    minWidth: minW(140),
  },
  { title: t('teamMembers.headers.player_types'), key: 'player_type_ids', minWidth: minW(140) },
  { title: t('teamMembers.headers.position'), key: 'position', minWidth: minW(96) },
  { title: t('teamMembers.headers.throws'), key: 'throws', minWidth: minW(64) },
  { title: t('teamMembers.headers.bats'), key: 'bats', minWidth: minW(64) },
  { title: 'カードver.', key: 'player_card_info', sortable: false, minWidth: minW(150) },
  { title: t('teamMembers.headers.cost'), value: 'cost', minWidth: minW(130) },
  {
    title: t('teamMembers.headers.costExcluded'),
    key: 'excluded_from_team_total',
    sortable: false,
    width: '80px',
    minWidth: minW(80),
  },
  {
    title: t('teamMembers.headers.actions'),
    key: 'actions',
    sortable: false,
    width: '100px',
    minWidth: minW(80),
  },
])

// --- Computed properties ---
const includedTeamPlayers = computed(() => {
  return teamPlayers.value.filter((p) => !p.excluded_from_team_total)
})

const totalTeamCost = computed(() => {
  return includedTeamPlayers.value.reduce((sum, p) => {
    const costPlayerForSelectedList = findCostPlayer(
      p.cost_players,
      selectedCostListId.value,
      p.player_card_id,
    )
    const costValue = costPlayerForSelectedList
      ? ((costPlayerForSelectedList as Record<CostType, number | null>)[p.selected_cost_type] ?? 0)
      : 0
    return sum + costValue
  }, 0)
})

// コスト上限超過の警告（チーム全体: 200固定）
const isCostOverLimit = computed(() => {
  return totalTeamCost.value > TEAM_TOTAL_MAX_COST
})

const costRatio = computed(() => Math.min(totalTeamCost.value / TEAM_TOTAL_MAX_COST, 1))

const costGaugeColor = computed(() => {
  const r = costRatio.value
  if (r >= 0.95) return 'error'
  if (r >= 0.85) return 'warning'
  return 'success'
})

// フィルタ
const positionFilter = ref<'all' | 'pitcher' | 'fielder'>('all')
const positionFilters = computed(() => [
  { value: 'all' as const, label: t('teamMembers.positionAll') },
  { value: 'pitcher' as const, label: t('teamMembers.positionPitcher') },
  { value: 'fielder' as const, label: t('teamMembers.positionFielder') },
])

const filteredTeamPlayers = computed(() => {
  if (positionFilter.value === 'pitcher') {
    return teamPlayers.value.filter((p) => p.position === 'pitcher')
  }
  if (positionFilter.value === 'fielder') {
    return teamPlayers.value.filter((p) => p.position !== 'pitcher')
  }
  return teamPlayers.value
})

const availablePlayers = computed(() => {
  if (!selectedCostListId.value) return []
  // 選択されたコスト一覧表にいずれかのコストが設定されている選手をフィルタリング
  // バリエーション対応: base/variant含む全エントリをチェック
  return allPlayers.value.filter((p) => {
    const costPlayersForList = p.cost_players.filter(
      (cp) => cp.cost_id === selectedCostListId.value,
    )
    if (costPlayersForList.length === 0) return false
    if (teamPlayers.value.some((tp) => tp.id === p.id)) return false
    // いずれかのエントリにコストが設定されていれば追加候補に含める
    return costPlayersForList.some(
      (cp) =>
        cp.normal_cost !== null ||
        cp.relief_only_cost !== null ||
        cp.pitcher_only_cost !== null ||
        cp.fielder_only_cost !== null ||
        cp.two_way_cost !== null,
    )
  })
})

// 追加候補のポジションフィルタ
const addPlayerPositionFilter = ref<'all' | 'pitcher' | 'fielder'>('all')
const addPlayerPositionFilters = computed(() => [
  { value: 'all' as const, label: t('teamMembers.positionAll') },
  { value: 'pitcher' as const, label: t('teamMembers.positionPitcher') },
  { value: 'fielder' as const, label: t('teamMembers.positionFielder') },
])

const filteredAvailablePlayers = computed(() => {
  if (addPlayerPositionFilter.value === 'pitcher') {
    return availablePlayers.value.filter((p) => p.position === 'pitcher')
  }
  if (addPlayerPositionFilter.value === 'fielder') {
    return availablePlayers.value.filter((p) => p.position !== 'pitcher')
  }
  return availablePlayers.value
})

const getPlayerCostLabel = (player: Player): string => {
  if (!selectedCostListId.value) return ''
  if (!player?.cost_players) return ''
  // バリエーション選手: base entryを優先、なければ最初のvariant entryを表示
  const costPlayer = findCostPlayer(player.cost_players, selectedCostListId.value)
  if (!costPlayer) return t('teamMembers.costDisplayLabels.noData')

  const parts: string[] = []
  if (costPlayer.normal_cost !== null)
    parts.push(`${t('teamMembers.costDisplayLabels.normal_cost')}: ${costPlayer.normal_cost}`)
  if (costPlayer.relief_only_cost !== null)
    parts.push(
      `${t('teamMembers.costDisplayLabels.relief_only_cost')}: ${costPlayer.relief_only_cost}`,
    )
  if (costPlayer.pitcher_only_cost !== null)
    parts.push(
      `${t('teamMembers.costDisplayLabels.pitcher_only_cost')}: ${costPlayer.pitcher_only_cost}`,
    )
  if (costPlayer.fielder_only_cost !== null)
    parts.push(
      `${t('teamMembers.costDisplayLabels.fielder_only_cost')}: ${costPlayer.fielder_only_cost}`,
    )
  if (costPlayer.two_way_cost !== null)
    parts.push(`${t('teamMembers.costDisplayLabels.two_way_cost')}: ${costPlayer.two_way_cost}`)
  return parts.length > 0
    ? `${t('teamMembers.costDisplayLabels.prefix')}: ${parts.join(' / ')}`
    : t('teamMembers.costDisplayLabels.noData')
}

const positionCounts = computed(() => {
  const counts: Record<string, number> = {
    pitcher: 0,
    catcher: 0,
    infielder: 0,
    outfielder: 0,
  }
  for (const player of teamPlayers.value) {
    if (player.position && player.position in counts) {
      counts[player.position]++
    }
  }
  return counts
})

// --- API Calls ---
const fetchAllPlayers = async () => {
  try {
    const response = await axios.get<Player[]>('/team_registration_players')
    allPlayers.value = response.data
  } catch (error) {
    showSnackbar(t('teamMembers.notifications.fetchPlayersFailed'), 'error')
    console.error('Failed to fetch players:', error)
  }
}

// 読む日付と区分は、GET と POST の両方に同じ値を送る。GET を日付なしで呼ぶと最新の写し、POST を日付なしで呼ぶと現在日の状態と比べるので、
// 読んだ値を送り直すだけで余計な変更記録が増えることがある。asOfDate が無い時は、シーズンの現在日を GET /teams/:id/season で読んで使う
const seasonCurrentDate = ref<string | null>(null)
const dateParams = computed<{ target_date?: string; phase?: string }>(() => {
  const date = props.asOfDate ?? seasonCurrentDate.value
  return date ? { target_date: date, phase: props.phase ?? 'pre_game' } : {}
})
// 保存が後の日付の検査で止まった時の違反（422 の violations）
const violations = ref<RosterViolation[]>([])

const fetchSeasonCurrentDate = async () => {
  if (props.asOfDate) return
  try {
    const response = await axios.get<{ current_date?: string }>(`/teams/${teamId.value}/season`)
    seasonCurrentDate.value = response.data?.current_date?.slice(0, 10) ?? null
  } catch {
    // シーズンが無いチームは日付なし（サーバが行を直接書く）
    seasonCurrentDate.value = null
  }
}

const fetchTeamPlayers = async () => {
  if (!selectedCostListId.value) return
  loadFailed.value = false
  try {
    const response = await axios.get<TeamPlayer[]>(`/teams/${teamId.value}/team_players`, {
      params: dateParams.value,
    })
    violations.value = []
    teamPlayers.value = response.data.map((player) => {
      let initialSelectedCostType: CostType = 'normal_cost' // Default to normal_cost

      const costPlayerForSelectedList = findCostPlayer(
        player.cost_players,
        selectedCostListId.value,
        player.player_card_id,
      )

      // Determine the initial selected cost type
      const availableOptions = getAvailableCostTypes(player)

      // 1. Try to use the selected_cost_type from backend if it's valid and has a non-null cost
      if (
        player.selected_cost_type &&
        availableOptions.some((opt) => {
          if (!costPlayerForSelectedList) return false

          const typedCostPlayer = costPlayerForSelectedList as Record<CostType, number | null>
          return opt.value === player.selected_cost_type && typedCostPlayer[opt.value] !== null
        })
      ) {
        initialSelectedCostType = player.selected_cost_type as CostType
      } else if (costPlayerForSelectedList?.normal_cost !== null) {
        // 2. If not, try normal_cost if it's available
        initialSelectedCostType = 'normal_cost'
      } else if (availableOptions.length > 0) {
        // 3. Otherwise, pick the first available option
        initialSelectedCostType = availableOptions[0].value
      } else {
        // 4. If no options are available, default to normal_cost (even if null)
        initialSelectedCostType = 'normal_cost'
      }

      // Calculate current_cost based on the determined initialSelectedCostType
      const costValue = costPlayerForSelectedList
        ? ((costPlayerForSelectedList as Record<CostType, number | null>)[
            initialSelectedCostType
          ] ?? 0)
        : 0

      return {
        ...player,
        selected_cost_type: initialSelectedCostType,
        current_cost: costValue,
        excluded_from_team_total: player.excluded_from_team_total ?? false,
        player_card_id: player.player_card_id ?? null,
        player_card_info: player.player_card_info ?? null,
      }
    })
  } catch (error) {
    loadFailed.value = true
    console.error('Failed to fetch team players:', error)
  }
}

watch(selectedCost, async () => {
  loading.value = true
  try {
    await fetchAllPlayers()
    await fetchTeamPlayers()
    await fetchPlayerTypes()
  } finally {
    loading.value = false
  }
})

// 「再読み込み」: コスト表が決まっていなければ最初から、決まっていれば選手だけを読み直す
const reload = async () => {
  if (!selectedCost.value) {
    await loadInitial()
    return
  }
  loading.value = true
  try {
    await fetchTeamPlayers()
  } finally {
    loading.value = false
  }
}

const fetchTeamName = async () => {
  if (!standalone.value) return
  try {
    const response = await axios.get<{ name?: string }>(`/teams/${teamId.value}`)
    teamName.value = response.data?.name ?? ''
  } catch {
    // チーム名が取れなくても画面は使える（バーは「チーム編成」だけを出す）
    teamName.value = ''
  }
}

const fetchPlayerTypes = async () => {
  try {
    const response = await axios.get<PlayerType[]>('/player-types')
    playerTypes.value = response.data
  } catch (error) {
    showSnackbar(t('teamMembers.notifications.fetchPlayerTypesFailed'), 'error')
    console.error('Failed to fetch player types:', error)
  }
}

// --- Player & Cost Management ---

const getAvailableCostTypes = (player: Player) => {
  const options: { value: CostType; text: string }[] = []
  const playerCardId = (player as TeamPlayer).player_card_id
  const costPlayerForSelectedList = findCostPlayer(
    player.cost_players,
    selectedCostListId.value,
    playerCardId,
  )

  if (!costPlayerForSelectedList) return [] // 選択されたコスト一覧表に紐づくコストデータがない場合は空を返す

  const addOption = (type: CostType, cost: number | null | undefined) => {
    if (cost !== null && cost !== undefined) {
      if (!player.available_cost_types || player.available_cost_types.includes(type)) {
        options.push({ value: type, text: `${t('teamMembers.costTypes.' + type)} (${cost})` })
      }
    }
  }

  addOption('normal_cost', costPlayerForSelectedList.normal_cost)
  addOption('relief_only_cost', costPlayerForSelectedList.relief_only_cost)
  addOption('pitcher_only_cost', costPlayerForSelectedList.pitcher_only_cost)
  addOption('fielder_only_cost', costPlayerForSelectedList.fielder_only_cost)
  addOption('two_way_cost', costPlayerForSelectedList.two_way_cost)

  return options
}

const updatePlayerCost = (player: TeamPlayer) => {
  const costPlayerForSelectedList = findCostPlayer(
    player.cost_players,
    selectedCostListId.value,
    player.player_card_id,
  )
  const costValue = costPlayerForSelectedList
    ? ((costPlayerForSelectedList as Record<CostType, number | null>)[player.selected_cost_type] ??
      0)
    : 0
  player.current_cost = costValue
}

// 登録画面で選べるカード: 現行カードセットの、公式戦で使えるもの。サーバ側でも同じ規則で拒む
const isRegistrableCard = (card: PlayerCardInfo) =>
  card.card_set_current !== false && !card.official_use_prohibited

async function fetchPlayerCards(playerId: number): Promise<PlayerCardInfo[]> {
  try {
    const res = await axios.get<{ player_cards: PlayerCardInfo[] }>('/player_cards', {
      params: { player_id: playerId, per_page: 100 },
    })
    return res.data.player_cards
  } catch {
    return []
  }
}

watch(selectedPlayer, async (newPlayer) => {
  selectedCardOptionKey.value = null
  availablePlayerCards.value = []
  playerCardTotal.value = 0
  if (!newPlayer) return
  fetchingCards.value = true
  try {
    const cards = await fetchPlayerCards(newPlayer.id)
    playerCardTotal.value = cards.length
    availablePlayerCards.value = cards.filter(isRegistrableCard)
    if (cardSetOptions.value.length > 0) {
      const normalOption = cardSetOptions.value.find((opt) => opt.card_set_name.includes('通常'))
      selectedCardOptionKey.value = normalOption?.option_key ?? cardSetOptions.value[0].option_key
    }
  } finally {
    fetchingCards.value = false
  }
})

const addPlayer = () => {
  if (!selectedPlayer.value) return

  if (teamPlayers.value.some((p) => p.id === selectedPlayer.value!.id)) {
    showSnackbar(t('teamMembers.notifications.playerAlreadyAdded'), 'warning')
    return
  }

  doAddPlayer()
}

const doAddPlayer = () => {
  if (!selectedPlayer.value) return

  // カードIDの解決: selectedCardOptionKey + player.position から適切なcard_idを先に決定
  let resolvedCardId: number | null = null
  let resolvedCardInfo: PlayerCardInfo | null = null

  if (selectedCardOptionKey.value !== null) {
    const selectedOption = cardSetOptions.value.find(
      (opt) => opt.option_key === selectedCardOptionKey.value,
    )
    if (selectedOption) {
      resolvedCardId = resolveCardIdFromCardSet(selectedOption, selectedPlayer.value.position)
      resolvedCardInfo = availablePlayerCards.value.find((c) => c.id === resolvedCardId) ?? null
    }
  } else if (availablePlayerCards.value.length === 1) {
    resolvedCardId = availablePlayerCards.value[0].id
    resolvedCardInfo = availablePlayerCards.value[0]
  }

  // カードID確定後にコスト検索（バリエーション対応）
  let initialCostType: CostType = 'normal_cost'
  let initialCost = 0

  const costPlayerForSelectedList = findCostPlayer(
    selectedPlayer.value.cost_players,
    selectedCostListId.value,
    resolvedCardId,
  )
  if (costPlayerForSelectedList) {
    const availableOptions = getAvailableCostTypes({
      ...selectedPlayer.value,
      player_card_id: resolvedCardId,
    } as TeamPlayer)
    if (availableOptions.length > 0) {
      initialCostType = availableOptions[0].value
      initialCost =
        (costPlayerForSelectedList as Record<CostType, number | null>)[initialCostType] ?? 0
    }
  }

  const newPlayer: TeamPlayer = {
    ...selectedPlayer.value,
    selected_cost_type: initialCostType,
    current_cost: initialCost,
    excluded_from_team_total: false,
    display_name: null,
    player_type_ids: [],
    player_card_id: resolvedCardId,
    player_card_info: resolvedCardInfo,
  }

  teamPlayers.value.push(newPlayer)
  selectedPlayer.value = null
  selectedCardOptionKey.value = null
  availablePlayerCards.value = []
  playerCardTotal.value = 0

  // Check limits and show warnings
  if (includedTeamPlayers.value.length > MAX_PLAYERS) {
    showSnackbar(t('teamMembers.notifications.maxPlayersExceeded', { max: MAX_PLAYERS }), 'warning')
  }
  if (totalTeamCost.value > TEAM_TOTAL_MAX_COST) {
    showSnackbar(
      t('teamMembers.notifications.costLimitExceeded', {
        cost: totalTeamCost.value,
        limit: TEAM_TOTAL_MAX_COST,
      }),
      'warning',
    )
  }
}

const removePlayer = (player: TeamPlayer) => {
  teamPlayers.value = teamPlayers.value.filter((p) => p.id !== player.id)
}

// --- Actions ---
const saveTeamMembers = async () => {
  if (!selectedCostListId.value) {
    showSnackbar(t('teamMembers.notifications.selectCostList'), 'error')
    return
  }
  try {
    const payload = {
      cost_list_id: selectedCostListId.value,
      players: teamPlayers.value.map((p) => ({
        player_id: p.id,
        selected_cost_type: p.selected_cost_type,
        excluded_from_team_total: p.excluded_from_team_total,
        display_name: p.display_name || null,
        player_card_id: p.player_card_id ?? null,
      })),
      ...dateParams.value,
    }
    const response = await axios.post<TeamPlayersSaveResponse>(
      `/teams/${teamId.value}/team_players`,
      payload,
    )
    showSnackbar(t('teamMembers.notifications.saveSuccess'), 'success')
    violations.value = []
    const warnings = response.data?.warnings ?? []
    for (const warning of warnings) {
      showSnackbar(`警告: ${warning}`, 'warning')
    }
  } catch (error: unknown) {
    const axiosError = error as {
      response?: {
        data?: {
          errors?: { player_id?: string[] }
          message?: string
          error?: string
          violations?: RosterViolation[]
        }
      }
    }
    violations.value = axiosError.response?.data?.violations ?? []
    const errorMsg =
      axiosError.response?.data?.errors?.player_id?.[0] ||
      axiosError.response?.data?.error ||
      axiosError.response?.data?.message ||
      t('teamMembers.notifications.saveFailed')
    showSnackbar(errorMsg, 'error')
    console.error('Failed to save team members:', error)
  }
}

const goBack = () => {
  router.back()
}

watch(
  () => [props.asOfDate, props.phase],
  () => {
    void fetchTeamPlayers()
  },
)

// シーズンの現在日とコスト表を読んで、コスト表を自動選択する（選択UIなし: 現在日時に対応するコスト表 or 最初の1件）。
// 選手の取得は selectedCost の watch が続ける
const loadInitial = async () => {
  loading.value = true
  loadFailed.value = false
  await fetchSeasonCurrentDate()
  try {
    const response = await axios.get<CostList[]>('/costs')
    const costLists = response.data
    const now = new Date()
    const currentCost = costLists.find((cost) => {
      const startDate = new Date(cost.start_date || '')
      const endDate = new Date(cost.end_date || '')
      return startDate <= now && (endDate >= now || !cost.end_date)
    })
    selectedCost.value = currentCost ?? costLists[0] ?? null
  } catch (error) {
    loadFailed.value = true
    console.error('Failed to fetch cost lists:', error)
  }
  // コスト表が決まらなければ watch(selectedCost) は走らない。読み込み中の表示はここで閉じる
  if (!selectedCost.value) loading.value = false
}

onMounted(async () => {
  if (!isTeamIdValid.value) return
  void fetchTeamName()
  await loadInitial()
})
</script>

<style scoped>
/* 埋め込み（シーズンのタブ・試合日ページ）の時も、単独の画面と同じ縦の間隔で積む */
.team-members--embedded {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
/* v-card-title は nowrap で、スマホ幅だと「合計人数 / 合計コスト」の右が切れる。折り返して全部を見せる */
.team-members__title {
  white-space: normal;
}
.team-members__add-row {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  gap: 12px;
}
.card-option {
  margin-right: 16px;
}

.card-option :deep(.v-label) {
  display: flex;
  align-items: center;
  gap: 8px;
  opacity: 1;
}

.card-option__thumb {
  flex: none;
  border-radius: 2px;
}

.team-members__add-select {
  flex: 1 1 320px;
  min-width: 0;
}
.team-members__add-button {
  flex: 0 0 auto;
}
</style>
