<!-- eslint-disable vue/valid-v-slot -->
<template>
  <div>
    <v-row v-if="isSeasonStartDate" class="mt-2">
      <v-col cols="12">
        <v-card variant="outlined">
          <v-card-title class="d-flex">
            {{ t('activeRoster.keyPlayerSelection') }}
            <v-spacer></v-spacer>
            <v-btn color="primary" variant="outlined" @click="saveKeyPlayer">
              {{ t('activeRoster.saveKeyPlayer') }}
            </v-btn>
          </v-card-title>
          <v-card-text>
            <v-select
              v-model="selectedKeyPlayerId"
              :items="availableKeyPlayers"
              item-title="player_name"
              item-value="team_membership_id"
              :label="t('activeRoster.selectKeyPlayer')"
              :hint="t('activeRoster.selectKeyPlayerHint')"
              clearable
            ></v-select>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <AbsenceInfo
      :season-id="seasonId"
      :current-date="currentDateFormatted"
      ref="absenceInfo"
      class="mt-2"
    />

    <PromotionCooldownInfo
      :cooldown-players="cooldownPlayers"
      :current-date="currentDateFormatted"
      class="mt-2"
    />

    <!-- 離脱終了間近の選手通知 -->
    <v-row v-if="nearEndAbsencePlayers.length > 0" class="mt-2">
      <v-col cols="12">
        <v-alert type="info" density="compact" elevation="2">
          <template #title>
            {{ t('activeRoster.absenceEndingSoon') }}
          </template>
          <p v-for="player in nearEndAbsencePlayers" :key="player.team_membership_id" class="mb-0">
            {{ player.player_name }}:
            {{ t(`enums.player_absence.absence_type.${player.absence_info!.absence_type}`) }}
            — {{ t('activeRoster.remainingDays', { days: player.absence_info!.remaining_days }) }}
          </p>
        </v-alert>
      </v-col>
    </v-row>

    <!-- 1軍制限サマリー alerts -->
    <v-row class="mt-2">
      <v-col cols="12">
        <v-alert
          v-if="firstSquadCostLimit !== null && firstSquadTotalCost > firstSquadCostLimit"
          type="warning"
          density="compact"
          class="mb-2"
        >
          {{
            t('activeRoster.costLimitExceeded', {
              cost: firstSquadTotalCost,
              limit: firstSquadCostLimit,
            })
          }}
        </v-alert>
        <v-alert
          v-if="firstSquadCostLimit === null && firstSquadPlayers.length > 0"
          type="error"
          density="compact"
          class="mb-2"
        >
          {{ t('activeRoster.belowMinimumPlayers', { min: FIRST_SQUAD_MIN_PLAYERS }) }}
        </v-alert>
        <v-alert
          v-if="outsideWorldFirstSquadCount > OUTSIDE_WORLD_LIMIT"
          type="warning"
          density="compact"
          class="mb-2"
        >
          {{
            t('activeRoster.outsideWorldLimitExceeded', {
              count: outsideWorldFirstSquadCount,
              limit: OUTSIDE_WORLD_LIMIT,
            })
          }}
        </v-alert>
      </v-col>
    </v-row>

    <!-- コストバー -->
    <v-row class="mt-1 mb-1">
      <v-col cols="12">
        <div class="d-flex justify-space-between align-center mb-1 text-body-2">
          <span>
            <strong>1軍コスト: </strong>
            <span
              :class="{
                'text-error font-weight-bold': costBarColor === 'error',
                'text-warning font-weight-bold': costBarColor === 'warning',
              }"
            >
              {{ firstSquadTotalCost }} / {{ firstSquadCostLimit ?? '-' }}
            </span>
          </span>
          <span class="text-caption text-medium-emphasis">
            {{ firstSquadPlayers.length }}/{{ MAX_FIRST_SQUAD_PLAYERS }}人 &nbsp;
            <span :class="{ 'text-error': outsideWorldFirstSquadCount > OUTSIDE_WORLD_LIMIT }">
              {{
                t('activeRoster.outsideWorldCount', {
                  count: outsideWorldFirstSquadCount,
                  max: OUTSIDE_WORLD_LIMIT,
                })
              }}
            </span>
          </span>
        </div>
        <v-progress-linear
          v-if="firstSquadCostLimit"
          :model-value="costBarValue"
          :color="costBarColor"
          height="8"
          rounded
        />
      </v-col>
    </v-row>

    <!-- 凡例 -->
    <v-row class="mb-2">
      <v-col cols="12">
        <div class="d-flex flex-wrap ga-2">
          <v-chip size="small" variant="tonal" color="deep-purple" prepend-icon="mdi-lock"
            >特例</v-chip
          >
          <v-chip size="small" variant="tonal" color="red" prepend-icon="mdi-hospital-box">
            {{ t('activeRoster.legend.injury') }}
          </v-chip>
          <v-chip size="small" variant="tonal" color="orange" prepend-icon="mdi-gavel">
            {{ t('activeRoster.legend.suspension') }}
          </v-chip>
          <v-chip size="small" variant="tonal" color="blue-grey" prepend-icon="mdi-wrench">
            {{ t('activeRoster.legend.reconditioning') }}
          </v-chip>
          <v-chip size="small" variant="tonal" color="amber" prepend-icon="mdi-timer-sand">
            {{ t('activeRoster.legend.cooldown') }}
          </v-chip>
          <v-chip size="small" variant="tonal" color="purple">外の世界</v-chip>
        </div>
      </v-col>
    </v-row>

    <!-- 1軍 / 2軍 2カラム -->
    <v-row align="start">
      <!-- 1軍 -->
      <v-col cols="12" md="6">
        <v-card variant="outlined">
          <v-card-title>
            <div class="d-flex align-center">
              <v-icon class="mr-1" color="primary">mdi-star</v-icon>
              {{ t('activeRoster.firstSquad') }}
              <v-spacer />
              <span class="text-body-2 text-medium-emphasis">
                {{ firstSquadPlayers.length }}/{{ MAX_FIRST_SQUAD_PLAYERS }}
              </span>
            </div>
          </v-card-title>
          <v-card-text class="pa-0">
            <v-table density="compact" class="roster-table">
              <thead>
                <tr>
                  <th class="text-left">#</th>
                  <th class="text-left">{{ t('activeRoster.headers.name') }}</th>
                  <th class="text-left">{{ t('activeRoster.headers.position') }}</th>
                  <th class="text-left">{{ t('activeRoster.headers.cost_type') }}</th>
                  <th class="text-right">{{ t('activeRoster.headers.cost') }}</th>
                  <th class="text-left">状態</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <template v-for="group in firstSquadGroups" :key="group.label">
                  <tr class="group-header-row">
                    <td colspan="7">{{ group.label }}</td>
                  </tr>
                  <tr
                    v-for="item in group.players"
                    :key="item.team_membership_id"
                    :class="getFirstSquadRowClass(item)"
                  >
                    <td class="text-caption">{{ item.number }}</td>
                    <td>
                      <div class="d-flex flex-column">
                        <div class="d-flex align-center flex-wrap ga-1">
                          <span class="text-body-2">{{ item.player_name }}</span>
                          <v-icon v-if="isKeyPlayer(item)" color="deep-purple" size="x-small"
                            >mdi-star</v-icon
                          >
                          <v-chip
                            v-if="item.is_outside_world"
                            size="x-small"
                            color="purple"
                            variant="tonal"
                            >外</v-chip
                          >
                        </div>
                        <div
                          v-if="item.player_types && item.player_types.length"
                          class="d-flex flex-wrap ga-1 mt-1"
                        >
                          <v-chip
                            v-for="pt in item.player_types"
                            :key="pt"
                            size="x-small"
                            variant="outlined"
                            density="compact"
                            >{{ pt }}</v-chip
                          >
                        </div>
                      </div>
                    </td>
                    <td class="text-caption">
                      {{ t(`baseball.shortPositions.${item.position}`) }}
                    </td>
                    <td>
                      <v-chip
                        v-if="item.selected_cost_type && item.selected_cost_type !== 'normal_cost'"
                        size="x-small"
                        variant="tonal"
                        :color="contractChipColor(item.selected_cost_type)"
                      >
                        {{ t(`baseball.construction.${item.selected_cost_type}`) }}
                      </v-chip>
                    </td>
                    <td class="text-right text-caption font-weight-bold">{{ item.cost }}</td>
                    <td>
                      <v-tooltip
                        v-if="isKeyPlayer(item)"
                        :text="t('activeRoster.keyPlayerLocked')"
                        location="top"
                      >
                        <template #activator="{ props }">
                          <v-chip
                            v-bind="props"
                            size="x-small"
                            color="deep-purple"
                            variant="tonal"
                            prepend-icon="mdi-lock"
                          >
                            {{ t('activeRoster.chip.special') }}
                          </v-chip>
                        </template>
                      </v-tooltip>
                      <v-tooltip
                        v-else-if="item.is_absent && item.absence_info"
                        :text="getAbsenceDetailTooltip(item)"
                        location="top"
                      >
                        <template #activator="{ props }">
                          <v-chip
                            v-bind="props"
                            size="x-small"
                            :color="getAbsenceColor(item)"
                            variant="tonal"
                          >
                            {{ absenceStatusLabel(item) }}
                          </v-chip>
                        </template>
                      </v-tooltip>
                    </td>
                    <td>
                      <!-- 特例選手: 降格不可 -->
                      <v-tooltip
                        v-if="isKeyPlayer(item)"
                        :text="t('activeRoster.keyPlayerLocked')"
                        location="top"
                      >
                        <template #activator="{ props }">
                          <span v-bind="props">
                            <v-btn
                              size="x-small"
                              color="blue-grey"
                              variant="elevated"
                              rounded
                              disabled
                              class="demote-btn"
                            >
                              <v-icon>mdi-arrow-down</v-icon>
                            </v-btn>
                          </span>
                        </template>
                      </v-tooltip>
                      <!-- 離脱中: 降格ボタン有効+ツールチップ -->
                      <v-tooltip
                        v-else-if="item.is_absent && item.absence_info"
                        :text="getAbsenceDetailTooltip(item)"
                        location="top"
                      >
                        <template #activator="{ props }">
                          <v-btn
                            v-bind="props"
                            size="x-small"
                            :color="getAbsenceColor(item)"
                            variant="elevated"
                            rounded
                            class="demote-btn"
                            @click="movePlayer(item, 'second')"
                          >
                            <v-icon>mdi-arrow-down</v-icon>
                          </v-btn>
                        </template>
                      </v-tooltip>
                      <!-- 通常: 降格ボタン -->
                      <v-btn
                        v-else
                        size="x-small"
                        color="blue-grey"
                        variant="elevated"
                        rounded
                        class="demote-btn"
                        @click="movePlayer(item, 'second')"
                      >
                        <v-icon>mdi-arrow-down</v-icon>
                      </v-btn>
                    </td>
                  </tr>
                </template>
              </tbody>
            </v-table>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- 2軍 -->
      <v-col cols="12" md="6">
        <v-card variant="outlined">
          <v-card-title>
            <div class="d-flex align-center">
              <v-icon class="mr-1">mdi-account-multiple</v-icon>
              {{ t('activeRoster.secondSquad') }}
            </div>
          </v-card-title>
          <v-card-text class="pa-0">
            <v-table density="compact" class="roster-table">
              <thead>
                <tr>
                  <th></th>
                  <th class="text-left">#</th>
                  <th class="text-left">{{ t('activeRoster.headers.name') }}</th>
                  <th class="text-left">{{ t('activeRoster.headers.position') }}</th>
                  <th class="text-left">{{ t('activeRoster.headers.cost_type') }}</th>
                  <th class="text-right">{{ t('activeRoster.headers.cost') }}</th>
                  <th class="text-left">状態</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="item in secondSquadPlayers"
                  :key="item.team_membership_id"
                  :class="getSecondSquadRowClass(item)"
                >
                  <td>
                    <!-- 再調整中: 昇格不可 -->
                    <v-tooltip
                      v-if="
                        item.is_absent &&
                        item.absence_info &&
                        item.absence_info.absence_type === 'reconditioning'
                      "
                      :text="t('activeRoster.reconditioningBlocked')"
                      location="top"
                    >
                      <template #activator="{ props }">
                        <v-chip
                          v-bind="props"
                          size="x-small"
                          color="blue-grey"
                          variant="tonal"
                          prepend-icon="mdi-wrench"
                        >
                          {{ t('activeRoster.chip.reconditioning') }}
                        </v-chip>
                      </template>
                    </v-tooltip>
                    <!-- 昇格クールダウン中 -->
                    <v-tooltip
                      v-else-if="isPlayerOnCooldown(item)"
                      :text="getCooldownTooltip(item)"
                      location="top"
                    >
                      <template #activator="{ props }">
                        <v-chip
                          v-bind="props"
                          size="x-small"
                          color="amber"
                          variant="tonal"
                          prepend-icon="mdi-timer-sand"
                        >
                          {{ t('activeRoster.chip.cooldown') }}
                        </v-chip>
                      </template>
                    </v-tooltip>
                    <!-- 離脱中(負傷/出場停止): 昇格ボタン有効+ツールチップ -->
                    <v-tooltip
                      v-else-if="item.is_absent && item.absence_info"
                      :text="getAbsenceDetailTooltip(item)"
                      location="top"
                    >
                      <template #activator="{ props }">
                        <v-btn
                          v-bind="props"
                          size="x-small"
                          :color="getAbsenceColor(item)"
                          variant="elevated"
                          rounded
                          class="promote-btn"
                          @click="handlePromotePlayer(item)"
                        >
                          <v-icon>mdi-arrow-up</v-icon>
                        </v-btn>
                      </template>
                    </v-tooltip>
                    <!-- 通常: 昇格ボタン -->
                    <v-btn
                      v-else
                      size="x-small"
                      color="primary"
                      variant="elevated"
                      rounded
                      class="promote-btn"
                      @click="handlePromotePlayer(item)"
                    >
                      <v-icon>mdi-arrow-up</v-icon>
                    </v-btn>
                  </td>
                  <td class="text-caption">{{ item.number }}</td>
                  <td>
                    <div class="d-flex flex-column">
                      <div class="d-flex align-center flex-wrap ga-1">
                        <span class="text-body-2">{{ item.player_name }}</span>
                        <v-chip
                          v-if="item.is_outside_world"
                          size="x-small"
                          color="purple"
                          variant="tonal"
                          >外</v-chip
                        >
                      </div>
                      <div
                        v-if="item.player_types && item.player_types.length"
                        class="d-flex flex-wrap ga-1 mt-1"
                      >
                        <v-chip
                          v-for="pt in item.player_types"
                          :key="pt"
                          size="x-small"
                          variant="outlined"
                          density="compact"
                          >{{ pt }}</v-chip
                        >
                      </div>
                    </div>
                  </td>
                  <td class="text-caption">{{ t(`baseball.shortPositions.${item.position}`) }}</td>
                  <td>
                    <v-chip
                      v-if="item.selected_cost_type && item.selected_cost_type !== 'normal_cost'"
                      size="x-small"
                      variant="tonal"
                      :color="contractChipColor(item.selected_cost_type)"
                    >
                      {{ t(`baseball.construction.${item.selected_cost_type}`) }}
                    </v-chip>
                  </td>
                  <td class="text-right text-caption font-weight-bold">{{ item.cost }}</td>
                  <td>
                    <v-chip
                      v-if="
                        item.is_absent &&
                        item.absence_info &&
                        item.absence_info.absence_type !== 'reconditioning'
                      "
                      size="x-small"
                      :color="getAbsenceColor(item)"
                      variant="tonal"
                    >
                      {{ absenceStatusLabel(item) }}
                    </v-chip>
                  </td>
                </tr>
              </tbody>
            </v-table>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-row class="mt-4">
      <v-col>
        <v-btn color="primary" variant="outlined" @click="saveRoster">{{
          t('activeRoster.saveRoster')
        }}</v-btn>
      </v-col>
    </v-row>

    <!-- 離脱中選手の昇格確認ダイアログ -->
    <v-dialog v-model="absenceConfirmDialog" max-width="480">
      <v-card>
        <v-card-title>{{ t('activeRoster.absenceWarning.title') }}</v-card-title>
        <v-card-text v-if="absenceConfirmPlayer">
          {{
            t('activeRoster.absenceWarning.message', {
              name: absenceConfirmPlayer.player_name,
              type: t(
                `enums.player_absence.absence_type.${absenceConfirmPlayer.absence_info!.absence_type}`,
              ),
              remaining:
                absenceConfirmPlayer.absence_info!.remaining_days != null
                  ? t('activeRoster.absenceWarning.remaining', {
                      days: absenceConfirmPlayer.absence_info!.remaining_days,
                    })
                  : t('activeRoster.absenceWarning.unknownEnd'),
            })
          }}
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="absenceConfirmDialog = false">{{ t('actions.cancel') }}</v-btn>
          <v-btn color="primary" @click="confirmPromoteAbsentPlayer">{{ t('actions.ok') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import AbsenceInfo from '@/components/AbsenceInfo.vue'
import PromotionCooldownInfo from '@/components/PromotionCooldownInfo.vue'
import type { RosterPlayer } from '@/types/rosterPlayer'

const props = defineProps<{
  teamId: number
}>()

const { t } = useI18n()
const seasonId = ref<number | null>(null)

// 1軍制限定数
const MAX_FIRST_SQUAD_PLAYERS = 29
const FIRST_SQUAD_MIN_PLAYERS = 25
const OUTSIDE_WORLD_LIMIT = 4
const COST_LIMIT_TIERS = [
  { minPlayers: 28, maxCost: 120 },
  { minPlayers: 27, maxCost: 119 },
  { minPlayers: 26, maxCost: 117 },
  { minPlayers: 25, maxCost: 114 },
]
const rosterPlayers = ref<RosterPlayer[]>([])
const currentDate = ref(new Date())
const currentDateFormatted = computed(() => currentDate.value.toISOString().split('T')[0])

const seasonStartDate = ref<Date | null>(null)
const selectedKeyPlayerId = ref<number | null>(null)

const fetchRoster = async () => {
  try {
    const response = await axios.get(`/teams/${props.teamId}/roster`)
    rosterPlayers.value = response.data.roster
    seasonId.value = response.data.season_id
    if (response.data.current_date) {
      currentDate.value = new Date(response.data.current_date)
    }
    if (response.data.season_start_date) {
      seasonStartDate.value = new Date(response.data.season_start_date)
    }
    if (response.data.key_player_id) {
      selectedKeyPlayerId.value = response.data.key_player_id
    }
  } catch (error) {
    console.error('Failed to fetch roster:', error)
  }
}

const firstSquadPlayers = computed(() => {
  return rosterPlayers.value.filter((p) => p.squad === 'first')
})

const secondSquadPlayers = computed(() => {
  return rosterPlayers.value.filter((p) => p.squad === 'second')
})

const cooldownPlayers = computed(() => {
  const now = currentDate.value
  return rosterPlayers.value.filter((p) => {
    if (p.cooldown_until) {
      const cooldownDate = new Date(p.cooldown_until)
      return now < cooldownDate
    }
    return false
  })
})

const firstSquadTotalCost = computed(() => {
  return firstSquadPlayers.value.reduce((sum, player) => sum + player.cost, 0)
})

const firstSquadCostLimit = computed(() => {
  const count = firstSquadPlayers.value.length
  const tier = COST_LIMIT_TIERS.find((t) => count >= t.minPlayers)
  return tier ? tier.maxCost : null
})

const outsideWorldFirstSquadCount = computed(() => {
  return firstSquadPlayers.value.filter((p) => p.is_outside_world).length
})

// 投手グルーピング: selected_cost_type='relief_only_cost' → 中継ぎ/クローザー, others → 先発
const firstSquadGroups = computed(() => {
  const pitchers = firstSquadPlayers.value.filter((p) => p.position === 'pitcher')
  const fielders = firstSquadPlayers.value.filter((p) => p.position !== 'pitcher')
  const spPitchers = pitchers.filter((p) => p.selected_cost_type !== 'relief_only_cost')
  const rpPitchers = pitchers.filter((p) => p.selected_cost_type === 'relief_only_cost')
  return [
    { label: '★ 先発ローテーション', players: spPitchers },
    { label: '◎ 中継ぎ / クローザー', players: rpPitchers },
    { label: '野手', players: fielders },
  ].filter((g) => g.players.length > 0)
})

// コストバー
const costBarValue = computed(() => {
  if (!firstSquadCostLimit.value) return 0
  return Math.min((firstSquadTotalCost.value / firstSquadCostLimit.value) * 100, 100)
})

const costBarColor = computed((): string => {
  if (!firstSquadCostLimit.value) return 'grey'
  const ratio = firstSquadTotalCost.value / firstSquadCostLimit.value
  if (ratio >= 1) return 'error'
  if (ratio >= 0.9) return 'warning'
  return 'success'
})

// 行ハイライト (カスタムテーブル用)
const getFirstSquadRowClass = (item: RosterPlayer): string => {
  if (isKeyPlayer(item)) return 'bg-deep-purple-lighten-5'
  if (item.is_absent && item.absence_info) {
    switch (item.absence_info.absence_type) {
      case 'injury':
        return 'bg-red-lighten-5'
      case 'suspension':
        return 'bg-orange-lighten-5'
      case 'reconditioning':
        return 'bg-blue-grey-lighten-5'
    }
  }
  return ''
}

const getSecondSquadRowClass = (item: RosterPlayer): string => {
  if (isPlayerOnCooldown(item)) return 'bg-amber-lighten-5'
  if (item.is_absent && item.absence_info) {
    switch (item.absence_info.absence_type) {
      case 'injury':
        return 'bg-red-lighten-5'
      case 'suspension':
        return 'bg-orange-lighten-5'
      case 'reconditioning':
        return 'bg-blue-grey-lighten-5'
    }
  }
  return ''
}

// 離脱状態ラベル (ロスタービュー用)
const absenceStatusLabel = (player: RosterPlayer): string => {
  if (!player.absence_info) return ''
  const days = player.absence_info.remaining_days
  switch (player.absence_info.absence_type) {
    case 'injury':
      return days != null ? `負傷 残${days}` : '負傷'
    case 'suspension':
      return days != null ? `停止 残${days}` : '出場停止'
    case 'reconditioning':
      return '再調整'
    default:
      return ''
  }
}

// 契約状態チップ色
const contractChipColor = (costType: string): string => {
  switch (costType) {
    case 'relief_only_cost':
      return 'indigo'
    case 'pitcher_only_cost':
      return 'blue'
    case 'fielder_only_cost':
      return 'teal'
    case 'two_way_cost':
      return 'cyan'
    default:
      return ''
  }
}

const isSeasonStartDate = computed(() => {
  if (!seasonStartDate.value) return false
  return currentDate.value.toDateString() === seasonStartDate.value.toDateString()
})

const availableKeyPlayers = computed(() => {
  return firstSquadPlayers.value
})

const isKeyPlayer = (player: RosterPlayer): boolean => {
  return (
    selectedKeyPlayerId.value !== null && player.team_membership_id === selectedKeyPlayerId.value
  )
}

const getAbsenceColor = (player: RosterPlayer): string => {
  if (!player.absence_info) return 'blue-grey'
  switch (player.absence_info.absence_type) {
    case 'injury':
      return 'red'
    case 'suspension':
      return 'orange'
    case 'reconditioning':
      return 'blue-grey'
    default:
      return 'blue-grey'
  }
}

const getCooldownTooltip = (player: RosterPlayer): string => {
  if (!player.cooldown_until) return ''
  const cooldownDate = new Date(player.cooldown_until)
  const formattedDate = cooldownDate.toLocaleDateString('ja-JP', {
    month: 'long',
    day: 'numeric',
  })
  return t('activeRoster.cooldownTooltip', { date: formattedDate })
}

const getAbsenceDetailTooltip = (player: RosterPlayer): string => {
  if (!player.absence_info) return ''
  const absenceType = t(`enums.player_absence.absence_type.${player.absence_info.absence_type}`)
  const reason = player.absence_info.reason ? `${player.absence_info.reason} ` : ''
  if (player.absence_info.remaining_days != null) {
    if (player.absence_info.duration_unit === 'games') {
      return t('activeRoster.absenceGamesTooltip', {
        type: absenceType,
        reason,
        days: player.absence_info.remaining_days,
      })
    }
    return t('activeRoster.absenceDaysTooltip', {
      type: absenceType,
      reason,
      days: player.absence_info.remaining_days,
    })
  }
  return `${absenceType}: ${reason}`
}

const nearEndAbsencePlayers = computed(() => {
  return rosterPlayers.value.filter((p) => {
    if (!p.is_absent || !p.absence_info) return false
    const remaining = p.absence_info.remaining_days
    return remaining !== null && remaining > 0 && remaining <= 3
  })
})

const absenceConfirmDialog = ref(false)
const absenceConfirmPlayer = ref<RosterPlayer | null>(null)

const handlePromotePlayer = (player: RosterPlayer) => {
  if (player.is_absent && player.absence_info) {
    absenceConfirmPlayer.value = player
    absenceConfirmDialog.value = true
  } else {
    movePlayer(player, 'first')
  }
}

const confirmPromoteAbsentPlayer = () => {
  if (absenceConfirmPlayer.value) {
    movePlayer(absenceConfirmPlayer.value, 'first')
  }
  absenceConfirmDialog.value = false
  absenceConfirmPlayer.value = null
}

const movePlayer = (player: RosterPlayer, targetSquad: 'first' | 'second') => {
  const index = rosterPlayers.value.findIndex(
    (p) => p.team_membership_id === player.team_membership_id,
  )
  if (index !== -1) {
    rosterPlayers.value[index].squad = targetSquad
  }
}

const isPlayerOnCooldown = (player: RosterPlayer) => {
  if (player.cooldown_until) {
    if (player.same_day_exempt) return false
    const cooldownDate = new Date(player.cooldown_until)
    return currentDate.value < cooldownDate
  }
  return false
}

const saveRoster = async () => {
  try {
    const updates = rosterPlayers.value.map((player) => ({
      team_membership_id: player.team_membership_id,
      squad: player.squad,
    }))
    await axios.post(`/teams/${props.teamId}/roster`, {
      roster_updates: updates,
      target_date: currentDate.value.toISOString().split('T')[0],
    })
    alert(t('activeRoster.saveSuccess'))
    fetchRoster()
  } catch (error: unknown) {
    console.error('Failed to save roster:', error)
    const axiosError = error as { response?: { data?: { error?: string } }; message?: string }
    alert(
      `${t('activeRoster.saveFailed')}: ${axiosError.response?.data?.error || axiosError.message}`,
    )
  }
}

const saveKeyPlayer = async () => {
  try {
    await axios.post(`/teams/${props.teamId}/key_player`, {
      key_player_id: selectedKeyPlayerId.value,
    })
    alert(t('activeRoster.keyPlayerSaveSuccess'))
  } catch (error: unknown) {
    console.error('Failed to save key player:', error)
    const axiosError = error as { response?: { data?: { error?: string } }; message?: string }
    alert(
      `${t('activeRoster.keyPlayerSaveFailed')}: ${axiosError.response?.data?.error || axiosError.message}`,
    )
  }
}

onMounted(fetchRoster)
</script>

<style scoped>
.promote-btn,
.demote-btn {
  transition: box-shadow 0.2s ease;
  min-width: 32px !important;
}
.promote-btn:hover:not(:disabled),
.demote-btn:hover:not(:disabled) {
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3) !important;
}

/* 投手グループヘッダー行 */
.group-header-row td {
  background-color: #ede7f6 !important;
  color: #7b1fa2;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.03em;
  padding: 4px 12px !important;
}

/* テーブルセルの余白調整 */
.roster-table :deep(td),
.roster-table :deep(th) {
  padding: 4px 8px !important;
}
</style>
