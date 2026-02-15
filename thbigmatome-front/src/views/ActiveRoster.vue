<!-- eslint-disable vue/valid-v-slot -->
<template>
  <v-container>
    <TeamNavigation :team-id="teamId" />
    <v-toolbar color="primary">
      <template #prepend>
        <h1 class="text-h5">{{ t('activeRoster.title') }}</h1>
      </template>
      <template #append>
        <p class="text-h5">{{ t('seasonPortal.currentDate') }}: {{ currentDateStr }}</p>
      </template>
    </v-toolbar>
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

    <!-- 1軍制限サマリー -->
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

    <v-row class="mt-4" align="start">
      <v-col cols="6">
        <v-card variant="outlined">
          <v-card-title>
            <div class="d-flex justify-space-between align-center">
              <h2 class="text-h5">{{ t('activeRoster.firstSquad') }}</h2>
              <div class="text-right">
                <div>
                  <span class="text-h6 mx-4"
                    >{{ t('activeRoster.firstSquadCount') }}: {{ firstSquadPlayers.length }} /
                    {{ MAX_FIRST_SQUAD_PLAYERS }}</span
                  >
                  <span
                    class="text-h6"
                    :class="{
                      'text-error':
                        firstSquadCostLimit !== null && firstSquadTotalCost > firstSquadCostLimit,
                    }"
                    >{{ t('activeRoster.firstSquadCost') }}: {{ firstSquadTotalCost }} /
                    {{ firstSquadCostLimit ?? '-' }}</span
                  >
                </div>
                <div>
                  <span
                    v-for="(count, type) in firstSquadPlayerTypeCounts"
                    :key="type"
                    class="text-body-2 mx-2"
                  >
                    {{ type }}: {{ count }}
                  </span>
                  <span
                    class="text-body-2 mx-2"
                    :class="{ 'text-error': outsideWorldFirstSquadCount > OUTSIDE_WORLD_LIMIT }"
                  >
                    {{
                      t('activeRoster.outsideWorldCount', {
                        count: outsideWorldFirstSquadCount,
                        max: OUTSIDE_WORLD_LIMIT,
                      })
                    }}
                  </span>
                </div>
              </div>
            </div>
          </v-card-title>
          <v-card-text>
            <v-data-table
              density="compact"
              :headers="firstHeaders"
              :items="firstSquadPlayers"
              hide-default-footer
              items-per-page="-1"
              :row-props="getFirstSquadRowProps"
            >
              <template #item.actions="{ item }">
                <v-tooltip
                  v-if="isKeyPlayer(item)"
                  :text="t('activeRoster.keyPlayerLocked')"
                  location="top"
                >
                  <template #activator="{ props }">
                    <v-icon v-bind="props" color="amber-darken-2" size="small">mdi-lock</v-icon>
                  </template>
                </v-tooltip>
                <v-btn
                  v-else
                  size="small"
                  color="blue-grey"
                  variant="elevated"
                  rounded
                  class="demote-btn"
                  @click="movePlayer(item, 'second')"
                  :disabled="isPlayerOnCooldown(item)"
                >
                  <v-icon start>mdi-arrow-down</v-icon>
                  {{ t('activeRoster.demoteButton') }}
                </v-btn>
              </template>
              <template #item.player_name="{ item }">
                <span>{{ item.player_name }}</span>
                <v-icon v-if="isKeyPlayer(item)" color="amber-darken-2" size="small" class="ml-1"
                  >mdi-star</v-icon
                >
                <v-tooltip
                  v-if="item.is_absent && item.absence_info"
                  :text="getAbsenceTooltip(item)"
                  location="top"
                >
                  <template #activator="{ props }">
                    <v-icon
                      v-bind="props"
                      :color="getAbsenceTypeColor(item.absence_info.absence_type)"
                      size="small"
                      class="ml-1"
                    >
                      {{ getAbsenceTypeIcon(item.absence_info.absence_type) }}
                    </v-icon>
                  </template>
                </v-tooltip>
              </template>
              <template #item.player_types="{ item }">
                <v-chip
                  v-for="player_type in item.player_types"
                  :key="player_type"
                  density="compact"
                  size="small"
                >
                  {{ player_type }}
                </v-chip>
              </template>
              <template #item.position="{ item }">
                {{ t(`baseball.shortPositions.${item.position}`) }}
              </template>
              <template #item.throwing_hand="{ item }">
                {{ t(`baseball.throwingHands.${item.throwing_hand}`) }}
              </template>
              <template #item.batting_hand="{ item }">
                {{ t(`baseball.battingHands.${item.batting_hand}`) }}
              </template>
              <template #item.selected_cost_type="{ item }">
                {{ t(`baseball.construction.${item.selected_cost_type}`) }}
              </template>
            </v-data-table>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col cols="6">
        <v-card variant="outlined">
          <v-card-title>
            <h2 class="text-h5">{{ t('activeRoster.secondSquad') }}</h2>
          </v-card-title>
          <!-- 凡例 -->
          <div class="d-flex flex-wrap ga-2 px-4 pb-2">
            <v-chip
              size="small"
              variant="tonal"
              color="amber-darken-2"
              prepend-icon="mdi-timer-sand"
            >
              {{ t('activeRoster.legend.cooldown') }}
            </v-chip>
            <v-chip size="small" variant="tonal" color="red" prepend-icon="mdi-hospital-box">
              {{ t('activeRoster.legend.injury') }}
            </v-chip>
            <v-chip size="small" variant="tonal" color="orange" prepend-icon="mdi-gavel">
              {{ t('activeRoster.legend.suspension') }}
            </v-chip>
            <v-chip size="small" variant="tonal" color="blue-grey" prepend-icon="mdi-wrench">
              {{ t('activeRoster.legend.reconditioning') }}
            </v-chip>
          </div>
          <v-card-text>
            <v-data-table
              density="compact"
              :headers="secondHeaders"
              :items="secondSquadPlayers"
              hide-default-footer
              items-per-page="-1"
              :row-props="getSecondSquadRowProps"
            >
              <template #item.actions="{ item }">
                <!-- 離脱中: 離脱種別アイコン（入れ替えボタンの代わり） -->
                <v-tooltip
                  v-if="item.is_absent && item.absence_info"
                  :text="getAbsenceDetailTooltip(item)"
                  location="top"
                >
                  <template #activator="{ props }">
                    <v-icon
                      v-bind="props"
                      :color="getAbsenceTypeColor(item.absence_info.absence_type)"
                      size="small"
                    >
                      {{ getAbsenceTypeIcon(item.absence_info.absence_type) }}
                    </v-icon>
                  </template>
                </v-tooltip>
                <!-- クールダウン中: disabled昇格ボタン -->
                <v-tooltip
                  v-else-if="isPlayerOnCooldown(item)"
                  :text="getCooldownTooltip(item)"
                  location="top"
                >
                  <template #activator="{ props }">
                    <v-btn
                      v-bind="props"
                      size="small"
                      color="primary"
                      variant="elevated"
                      rounded
                      class="promote-btn"
                      disabled
                    >
                      <v-icon start>mdi-arrow-up</v-icon>
                      {{ t('activeRoster.promoteButton') }}
                    </v-btn>
                  </template>
                </v-tooltip>
                <!-- 通常: 昇格ボタン -->
                <v-btn
                  v-else
                  size="small"
                  color="primary"
                  variant="elevated"
                  rounded
                  class="promote-btn"
                  @click="handlePromotePlayer(item)"
                >
                  <v-icon start>mdi-arrow-up</v-icon>
                  {{ t('activeRoster.promoteButton') }}
                </v-btn>
              </template>
              <template #item.player_name="{ item }">
                <v-tooltip
                  v-if="isPlayerOnCooldown(item)"
                  :text="getCooldownTooltip(item)"
                  location="top"
                >
                  <template #activator="{ props }">
                    <v-icon v-bind="props" color="amber-darken-2" size="small" class="mr-1"
                      >mdi-timer-sand</v-icon
                    >
                  </template>
                </v-tooltip>
                <span>{{ item.player_name }}</span>
              </template>
              <template #item.player_types="{ item }">
                <v-chip
                  v-for="player_type in item.player_types"
                  :key="player_type"
                  density="compact"
                  size="small"
                >
                  {{ player_type }}
                </v-chip>
              </template>
              <template #item.position="{ item }">
                {{ t(`baseball.shortPositions.${item.position}`) }}
              </template>
              <template #item.throwing_hand="{ item }">
                {{ t(`baseball.throwingHands.${item.throwing_hand}`) }}
              </template>
              <template #item.batting_hand="{ item }">
                {{ t(`baseball.battingHands.${item.batting_hand}`) }}
              </template>
              <template #item.selected_cost_type="{ item }">
                {{ t(`baseball.construction.${item.selected_cost_type}`) }}
              </template>
            </v-data-table>
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
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import AbsenceInfo from '@/components/AbsenceInfo.vue'
import PromotionCooldownInfo from '@/components/PromotionCooldownInfo.vue'
import TeamNavigation from '@/components/TeamNavigation.vue'
import type { RosterPlayer } from '@/types/rosterPlayer'

const { t } = useI18n()
const route = useRoute()
const teamId = route.params.teamId
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
const currentDateStr = computed(() => {
  return currentDate.value.toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' })
})

const currentDateFormatted = computed(() => currentDate.value.toISOString().split('T')[0])

const seasonStartDate = ref<Date | null>(null)
const selectedKeyPlayerId = ref<number | null>(null)

const headers = [
  { title: t('activeRoster.headers.number'), key: 'number' },
  { title: t('activeRoster.headers.name'), key: 'player_name' },
  { title: t('activeRoster.headers.player_types'), key: 'player_types' },
  { title: t('activeRoster.headers.position'), key: 'position' },
  { title: t('activeRoster.headers.throws'), key: 'throwing_hand' },
  { title: t('activeRoster.headers.bats'), key: 'batting_hand' },
  { title: t('activeRoster.headers.cost_type'), value: 'selected_cost_type' },
  { title: t('activeRoster.headers.cost'), key: 'cost' },
]
const firstHeaders = [
  ...headers,
  { title: t('activeRoster.headers.actions'), sortable: false, key: 'actions' },
]

const secondHeaders = [
  { title: t('activeRoster.headers.actions'), sortable: false, key: 'actions' },
  ...headers,
]

const fetchRoster = async () => {
  try {
    const response = await axios.get(`/teams/${teamId}/roster`)
    rosterPlayers.value = response.data.roster
    console.log('Fetched roster:', rosterPlayers.value)
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

// 1軍人数別コスト上限（人数不足時はnull=登録禁止）
const firstSquadCostLimit = computed(() => {
  const count = firstSquadPlayers.value.length
  const tier = COST_LIMIT_TIERS.find((t) => count >= t.minPlayers)
  return tier ? tier.maxCost : null
})

// 1軍の外の世界枠選手数
const outsideWorldFirstSquadCount = computed(() => {
  return firstSquadPlayers.value.filter((p) => p.is_outside_world).length
})

const firstSquadPlayerTypeCounts = computed(() => {
  const counts: { [key: string]: number } = {}
  firstSquadPlayers.value.forEach((player) => {
    player.player_types.forEach((type) => {
      counts[type] = (counts[type] || 0) + 1
    })
  })
  return counts
})

const isSeasonStartDate = computed(() => {
  if (!seasonStartDate.value) return false
  return currentDate.value.toDateString() === seasonStartDate.value.toDateString()
})

const availableKeyPlayers = computed(() => {
  return firstSquadPlayers.value // All first squad players are potential key players
})

const isKeyPlayer = (player: RosterPlayer): boolean => {
  return (
    selectedKeyPlayerId.value !== null && player.team_membership_id === selectedKeyPlayerId.value
  )
}

const getFirstSquadRowProps = ({ item }: { item: RosterPlayer }) => {
  if (isKeyPlayer(item)) {
    return { class: 'bg-amber-lighten-5' }
  }
  return {}
}

// 2軍テーブル行の背景色（クールダウン優先、次に離脱種別）
const getSecondSquadRowProps = ({ item }: { item: RosterPlayer }) => {
  if (isPlayerOnCooldown(item)) {
    return { class: 'bg-amber-lighten-5' }
  }
  if (item.is_absent && item.absence_info) {
    switch (item.absence_info.absence_type) {
      case 'injury':
        return { class: 'bg-red-lighten-5' }
      case 'suspension':
        return { class: 'bg-orange-lighten-5' }
      case 'reconditioning':
        return { class: 'bg-blue-grey-lighten-5' }
    }
  }
  return {}
}

// クールダウンのツールチップ
const getCooldownTooltip = (player: RosterPlayer): string => {
  if (!player.cooldown_until) return ''
  const cooldownDate = new Date(player.cooldown_until)
  const formattedDate = cooldownDate.toLocaleDateString('ja-JP', {
    month: 'long',
    day: 'numeric',
  })
  return t('activeRoster.cooldownTooltip', { date: formattedDate })
}

// 離脱種別ごとのアイコン
const getAbsenceTypeIcon = (absenceType: string): string => {
  switch (absenceType) {
    case 'injury':
      return 'mdi-hospital-box'
    case 'suspension':
      return 'mdi-gavel'
    case 'reconditioning':
      return 'mdi-wrench'
    default:
      return 'mdi-alert'
  }
}

// 離脱種別ごとの色
const getAbsenceTypeColor = (absenceType: string): string => {
  switch (absenceType) {
    case 'injury':
      return 'red'
    case 'suspension':
      return 'orange'
    case 'reconditioning':
      return 'blue-grey'
    default:
      return 'grey'
  }
}

// 離脱の詳細ツールチップ（2軍テーブル用）
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

// 離脱終了間近（3日以内）の選手
const nearEndAbsencePlayers = computed(() => {
  return rosterPlayers.value.filter((p) => {
    if (!p.is_absent || !p.absence_info) return false
    const remaining = p.absence_info.remaining_days
    return remaining !== null && remaining > 0 && remaining <= 3
  })
})

// 離脱中選手のツールチップ
const getAbsenceTooltip = (player: RosterPlayer): string => {
  if (!player.absence_info) return ''
  const absenceType = t(`enums.player_absence.absence_type.${player.absence_info.absence_type}`)
  const reason = player.absence_info.reason || ''
  if (player.absence_info.remaining_days != null) {
    return `${absenceType}: ${reason} (${t('activeRoster.remainingDays', { days: player.absence_info.remaining_days })})`
  }
  return `${absenceType}: ${reason}`
}

// 離脱中選手の昇格確認ダイアログ
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
    if (player.same_day_exempt) return false // Same-day promotion+demotion: no cooldown enforcement
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
    await axios.post(`/teams/${teamId}/roster`, {
      roster_updates: updates,
      target_date: currentDate.value.toISOString().split('T')[0],
    })
    alert(t('activeRoster.saveSuccess'))
    fetchRoster() // Re-fetch to update cooldowns and status
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
    await axios.post(`/teams/${teamId}/key_player`, {
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
}
.promote-btn:hover:not(:disabled),
.demote-btn:hover:not(:disabled) {
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3) !important;
}
</style>
