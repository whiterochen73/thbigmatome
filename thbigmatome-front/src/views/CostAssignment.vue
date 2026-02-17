<template>
  <v-container fluid>
    <v-card>
      <v-card-title>
        {{ t('costAssignment.title') }}
      </v-card-title>
      <v-card-text>
        <CostListSelect v-model="selectedCost" :label="t('costAssignment.costList')" />
        <v-data-table
          :headers="headers"
          :items="players"
          :loading="loading"
          class="elevation-1"
          density="compact"
          items-per-page="-1"
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
              :disabled="
                costDef.requiredPlayerTypeId !== null &&
                !item.player_types.some((pt) => pt.id === costDef.requiredPlayerTypeId)
              "
              style="width: 80px"
              density="compact"
              hide-details="auto"
            ></v-text-field>
          </template>
          <template #[`item.name`]="{ item }">
            {{ item.name }}
          </template>
          <template #[`item.player_types`]="{ item }">
            <v-chip v-for="type in item.player_types" :key="type.id">{{ type.name }}</v-chip>
          </template>
        </v-data-table>
      </v-card-text>
      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn color="primary" @click="saveAssignments" :disabled="loading">
          {{ t('costAssignment.save') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-container>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import { useI18n } from 'vue-i18n'
import type { CostList } from '@/types/costList'
import type { CostPlayer } from '@/types/costPlayer'
import CostListSelect from '@/components/shared/CostListSelect.vue'

const { t } = useI18n()
const { showSnackbar } = useSnackbar()

const players = ref<CostPlayer[]>([])
const selectedCost = ref<CostList | null>(null)
const loading = ref(false)

const costDefinitions = [
  { key: 'cost', model: 'normal_cost', requiredPlayerTypeId: null },
  { key: 'relief_only_cost', model: 'relief_only_cost', requiredPlayerTypeId: 9 },
  { key: 'pitcher_only_cost', model: 'pitcher_only_cost', requiredPlayerTypeId: 8 },
  { key: 'fielder_only_cost', model: 'fielder_only_cost', requiredPlayerTypeId: 8 },
  { key: 'two_way_cost', model: 'two_way_cost', requiredPlayerTypeId: 2 },
]

const headers = ref([
  { title: t('costAssignment.headers.number'), key: 'number' },
  { title: t('costAssignment.headers.name'), key: 'name' },
  { title: t('costAssignment.headers.player_types'), key: 'player_types' },
  ...costDefinitions.map((cost) => ({
    title: t(`costAssignment.headers.${cost.key}`),
    key: cost.key,
    sortable: false,
  })),
])

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
  try {
    const response = await axios.get<CostPlayer[]>(
      `/cost_assignments?cost_id=${selectedCost.value.id}`,
    )
    console.log('Fetched players:', response.data)
    players.value = response.data.map((player) => ({
      ...player,
      normal_cost: player.normal_cost || null,
      relief_only_cost: player.relief_only_cost || null,
      pitcher_only_cost: player.pitcher_only_cost || null,
      fielder_only_cost: player.fielder_only_cost || null,
      two_way_cost: player.two_way_cost || null,
    }))
  } catch {
    showSnackbar('選手情報の取得に失敗しました。', 'error')
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
    // APIに保存する処理を実装
    const assignments = {
      cost_id: selectedCost.value.id,
      players: players.value.map((player) => ({
        player_id: player.id,
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
