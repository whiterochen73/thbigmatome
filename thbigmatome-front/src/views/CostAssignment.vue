<template>
  <PageLayout width="wide">
    <v-card>
      <v-card-text>
        <CostListSelect v-model="selectedCost" :label="t('costAssignment.costList')" />
        <AsyncState
          :loading="loading"
          :error="fetchFailed"
          :error-message="t('costAssignment.notifications.fetchPlayersFailed')"
          :empty="players.length === 0"
          empty-icon="mdi-account-off-outline"
          :empty-message="t('costAssignment.noPlayers')"
          @retry="fetchPlayers"
        >
          <v-data-table
            :headers="headers"
            :items="players"
            density="compact"
            items-per-page="-1"
            :row-props="rowProps"
          >
            <template
              v-for="costDef in costDefinitions"
              :key="costDef.key"
              v-slot:[`item.${costDef.key}`]="{ item }"
            >
              <v-text-field
                v-model.number="item[costDef.model]"
                type="number"
                min="1"
                :rules="[rules.positiveInteger]"
                :disabled="!item.available_cost_types?.includes(costDef.model)"
                style="width: 80px"
                density="compact"
                hide-details="auto"
              ></v-text-field>
            </template>
            <template #[`item.name`]="{ item }">
              <span>{{ item.name }}</span>
              <v-chip
                v-if="item.variant"
                size="x-small"
                color="state-neutral"
                variant="flat"
                class="ml-1"
              >
                {{ item.variant }}
              </v-chip>
            </template>
            <template #[`item.player_types`]="{ item }">
              <v-chip v-for="type in item.player_types" :key="type.id">{{ type.name }}</v-chip>
            </template>
          </v-data-table>
        </AsyncState>
      </v-card-text>
      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn color="action" variant="flat" @click="saveAssignments" :disabled="loading">
          {{ t('costAssignment.save') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </PageLayout>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import { useI18n } from 'vue-i18n'
import type { CostList } from '@/types/costList'
import type { CostPlayer } from '@/types/costPlayer'
import AsyncState from '@/components/shared/AsyncState.vue'
import CostListSelect from '@/components/shared/CostListSelect.vue'
import PageLayout from '@/components/shared/PageLayout.vue'
import { useColumnMinWidth } from '@/composables/useColumnMinWidth'

const { t } = useI18n()
const { showSnackbar } = useSnackbar()

const players = ref<CostPlayer[]>([])
const selectedCost = ref<CostList | null>(null)
const loading = ref(false)
const fetchFailed = ref(false)

const costDefinitions = [
  { key: 'cost', model: 'normal_cost', requiredPlayerTypeId: null },
  { key: 'relief_only_cost', model: 'relief_only_cost', requiredPlayerTypeId: 9 },
  { key: 'pitcher_only_cost', model: 'pitcher_only_cost', requiredPlayerTypeId: 8 },
  { key: 'fielder_only_cost', model: 'fielder_only_cost', requiredPlayerTypeId: 8 },
  { key: 'two_way_cost', model: 'two_way_cost', requiredPlayerTypeId: 2 },
]

const minW = useColumnMinWidth()
const headers = computed(() => [
  { title: t('costAssignment.headers.number'), key: 'number', minWidth: minW(64) },
  // 横に比べる・入力する表なので縦積みにせず、スマホでは横スクロール。名前の列は左に固定する
  { title: t('costAssignment.headers.name'), key: 'name', fixed: true, minWidth: minW(150) },
  { title: t('costAssignment.headers.player_types'), key: 'player_types', minWidth: minW(140) },
  ...costDefinitions.map((cost) => ({
    title: t(`costAssignment.headers.${cost.key}`),
    key: cost.key,
    sortable: false,
    minWidth: minW(110),
  })),
])

const rowProps = (item: { item: CostPlayer }) => {
  return item.item.variant ? { class: 'bg-surface-variant' } : {}
}

const rules = {
  positiveInteger: (value: number | null) => {
    if (value === null || value === undefined) return true
    if (!Number.isInteger(value)) return '整数を入力してください'
    if (value < 1) return '1以上の整数を入力してください'
    return true
  },
}

watch(
  selectedCost,
  (newValue) => {
    if (newValue && newValue.id) {
      fetchPlayers()
    } else {
      players.value = []
    }
  },
  { immediate: true },
)

const fetchPlayers = async () => {
  if (!selectedCost.value) return
  loading.value = true
  fetchFailed.value = false
  try {
    const response = await axios.get<CostPlayer[]>(
      `/cost_assignments?cost_id=${selectedCost.value.id}`,
    )
    players.value = response.data.map((player) => ({
      ...player,
      normal_cost: player.normal_cost || null,
      relief_only_cost: player.relief_only_cost || null,
      pitcher_only_cost: player.pitcher_only_cost || null,
      fielder_only_cost: player.fielder_only_cost || null,
      two_way_cost: player.two_way_cost || null,
    }))
  } catch {
    // 取得の失敗はページ内のアラート（AsyncState）で出す。スナックバーは保存の成否だけ
    fetchFailed.value = true
  } finally {
    loading.value = false
  }
}

const saveAssignments = async () => {
  if (!selectedCost.value) {
    showSnackbar('コスト一覧が選択されていません。', 'warning')
    return
  }
  loading.value = true
  try {
    const assignments = {
      cost_id: selectedCost.value.id,
      players: players.value.map((player) => ({
        player_id: player.id,
        player_card_id: player.player_card_id ?? null,
        normal_cost: player.normal_cost,
        relief_only_cost: player.relief_only_cost,
        pitcher_only_cost: player.pitcher_only_cost,
        fielder_only_cost: player.fielder_only_cost,
        two_way_cost: player.two_way_cost,
      })),
    }

    await axios.post('/cost_assignments', { assignments })

    showSnackbar('コスト一覧を保存しました', 'success')
  } catch (error) {
    console.error(error)
    showSnackbar('コスト一覧の保存に失敗しました', 'error')
  } finally {
    loading.value = false
  }
}
</script>
