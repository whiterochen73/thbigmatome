<template>
  <v-container>
    <!-- ページヘッダー + コストサマリー -->
    <v-row align="center" class="mb-2">
      <v-col cols="12" md="6">
        <h1 class="text-h5">{{ competitionName }} — ロスター管理</h1>
      </v-col>
      <v-col cols="12" md="6">
        <v-card variant="outlined" class="pa-2">
          <div class="d-flex align-center gap-4 flex-wrap">
            <div>
              <span class="text-caption">全体コスト</span>
              <span
                class="ml-1 font-weight-bold"
                :class="costCheck?.current_total_cost > costCheck?.total_limit ? 'text-error' : ''"
              >
                {{ costCheck?.current_total_cost ?? '-' }} / {{ costCheck?.total_limit ?? 200 }}
              </span>
            </div>
            <v-divider vertical class="mx-2" />
            <div>
              <span class="text-caption">1軍コスト</span>
              <span
                class="ml-1 font-weight-bold"
                :class="
                  costCheck?.first_squad_cost > costCheck?.first_squad_limit ? 'text-error' : ''
                "
              >
                {{ costCheck?.first_squad_cost ?? '-' }} /
                {{ costCheck?.first_squad_limit ?? '-' }} ({{
                  costCheck?.first_squad_count ?? 0
                }}名)
              </span>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- コスト超過アラート -->
    <v-alert
      v-if="costCheck && !costCheck.valid && costCheck.errors.length > 0"
      type="error"
      variant="tonal"
      class="mb-3"
      data-testid="cost-error-alert"
    >
      <ul class="pl-4">
        <li v-for="err in costCheck.errors" :key="err">{{ err }}</li>
      </ul>
    </v-alert>

    <v-card>
      <v-tabs v-model="activeTab" color="primary">
        <v-tab value="first_squad">1軍</v-tab>
        <v-tab value="second_squad">2軍</v-tab>
      </v-tabs>

      <v-card-text>
        <v-tabs-window v-model="activeTab">
          <!-- 1軍タブ -->
          <v-tabs-window-item value="first_squad">
            <div class="d-flex justify-end mb-2">
              <v-btn
                color="primary"
                variant="tonal"
                prepend-icon="mdi-account-plus"
                @click="openAddDialog('first_squad')"
              >
                選手追加
              </v-btn>
            </div>
            <v-data-table
              :headers="rosterHeaders"
              :items="firstSquadPlayers"
              :loading="loading"
              density="compact"
              data-testid="first-squad-table"
            >
              <template v-slot:[`item.contract_type`]="{ item }">
                {{ item.is_reliever ? '中継ぎ' : '先発' }}
              </template>
              <template v-slot:[`item.actions`]="{ item }">
                <v-btn
                  size="small"
                  variant="outlined"
                  color="error"
                  @click="removePlayer(item.player_card_id)"
                  data-testid="remove-btn"
                >
                  除外
                </v-btn>
              </template>
            </v-data-table>
          </v-tabs-window-item>

          <!-- 2軍タブ -->
          <v-tabs-window-item value="second_squad">
            <div class="d-flex justify-end mb-2">
              <v-btn
                color="primary"
                variant="tonal"
                prepend-icon="mdi-account-plus"
                @click="openAddDialog('second_squad')"
              >
                選手追加
              </v-btn>
            </div>
            <v-data-table
              :headers="rosterHeaders"
              :items="secondSquadPlayers"
              :loading="loading"
              density="compact"
              data-testid="second-squad-table"
            >
              <template v-slot:[`item.contract_type`]="{ item }">
                {{ item.is_reliever ? '中継ぎ' : '先発' }}
              </template>
              <template v-slot:[`item.actions`]="{ item }">
                <v-btn
                  size="small"
                  variant="outlined"
                  color="error"
                  @click="removePlayer(item.player_card_id)"
                  data-testid="remove-btn"
                >
                  除外
                </v-btn>
              </template>
            </v-data-table>
          </v-tabs-window-item>
        </v-tabs-window>
      </v-card-text>
    </v-card>

    <!-- 選手追加ダイアログ -->
    <v-dialog v-model="addDialog" max-width="600px">
      <v-card>
        <v-card-title
          >選手追加（{{ addTargetSquad === 'first_squad' ? '1軍' : '2軍' }}）</v-card-title
        >
        <v-card-text>
          <v-text-field
            v-model="searchQuery"
            label="選手名検索"
            density="compact"
            prepend-inner-icon="mdi-magnify"
            class="mb-3"
            @input="searchPlayers"
          />
          <v-data-table
            :headers="searchHeaders"
            :items="searchResults"
            :loading="searching"
            density="compact"
            select-strategy="single"
          >
            <template v-slot:[`item.select`]="{ item }">
              <v-btn
                size="small"
                color="primary"
                variant="tonal"
                @click="addPlayer(item.id)"
                :loading="adding"
              >
                追加
              </v-btn>
            </template>
          </v-data-table>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="addDialog = false">閉じる</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'

interface RosterPlayer {
  player_card_id: number
  player_name: string
  squad: 'first_squad' | 'second_squad'
  is_reliever: boolean
  cost: number
}

interface CostCheckResult {
  valid: boolean
  errors: string[]
  current_total_cost: number
  total_limit: number
  first_squad_cost: number
  first_squad_limit: number
  first_squad_count: number
}

interface PlayerSearchResult {
  id: number
  player_name: string
  cost: number
  is_reliever: boolean
}

interface Competition {
  id: number
  name: string
}

const route = useRoute()
const competitionId = computed(() => route.params.id as string)
const teamId = computed(() => route.params.teamId as string)

const competitionName = ref('')
const firstSquadPlayers = ref<RosterPlayer[]>([])
const secondSquadPlayers = ref<RosterPlayer[]>([])
const costCheck = ref<CostCheckResult | null>(null)
const loading = ref(false)
const activeTab = ref<'first_squad' | 'second_squad'>('first_squad')

const addDialog = ref(false)
const addTargetSquad = ref<'first_squad' | 'second_squad'>('first_squad')
const searchQuery = ref('')
const searchResults = ref<PlayerSearchResult[]>([])
const searching = ref(false)
const adding = ref(false)

const rosterHeaders = [
  { title: '選手名', key: 'player_name' },
  { title: '契約種別', key: 'contract_type', sortable: false },
  { title: 'コスト', key: 'cost', width: '80px' },
  { title: 'アクション', key: 'actions', sortable: false, width: '100px' },
]

const searchHeaders = [
  { title: '選手名', key: 'player_name' },
  { title: 'コスト', key: 'cost', width: '80px' },
  { title: '種別', key: 'is_reliever', sortable: false },
  { title: '', key: 'select', sortable: false, width: '80px' },
]

onMounted(async () => {
  await Promise.all([fetchCompetitionName(), fetchRoster(), fetchCostCheck()])
})

async function fetchCompetitionName() {
  try {
    const res = await axios.get<Competition>(`/competitions/${competitionId.value}`)
    competitionName.value = res.data.name
  } catch {
    competitionName.value = `大会 #${competitionId.value}`
  }
}

async function fetchRoster() {
  loading.value = true
  try {
    const res = await axios.get<{ first_squad: RosterPlayer[]; second_squad: RosterPlayer[] }>(
      `/competitions/${competitionId.value}/roster`,
      { params: { team_id: teamId.value } },
    )
    firstSquadPlayers.value = res.data.first_squad
    secondSquadPlayers.value = res.data.second_squad
  } catch (error) {
    console.error('Error fetching roster:', error)
  } finally {
    loading.value = false
  }
}

async function fetchCostCheck() {
  try {
    const res = await axios.get<CostCheckResult>(
      `/competitions/${competitionId.value}/roster/cost_check`,
      { params: { team_id: teamId.value } },
    )
    costCheck.value = res.data
  } catch (error) {
    console.error('Error fetching cost check:', error)
  }
}

function openAddDialog(squad: 'first_squad' | 'second_squad') {
  addTargetSquad.value = squad
  searchQuery.value = ''
  searchResults.value = []
  addDialog.value = true
}

async function searchPlayers() {
  if (!searchQuery.value.trim()) {
    searchResults.value = []
    return
  }
  searching.value = true
  try {
    const res = await axios.get<PlayerSearchResult[]>('/player_cards', {
      params: { q: searchQuery.value },
    })
    searchResults.value = res.data
  } catch (error) {
    console.error('Error searching players:', error)
  } finally {
    searching.value = false
  }
}

async function addPlayer(playerCardId: number) {
  adding.value = true
  try {
    await axios.post(
      `/competitions/${competitionId.value}/roster/players?team_id=${teamId.value}`,
      {
        player_card_id: playerCardId,
        squad: addTargetSquad.value,
      },
    )
    addDialog.value = false
    await Promise.all([fetchRoster(), fetchCostCheck()])
  } catch (error) {
    console.error('Error adding player:', error)
  } finally {
    adding.value = false
  }
}

async function removePlayer(playerCardId: number) {
  try {
    await axios.delete(
      `/competitions/${competitionId.value}/roster/players/${playerCardId}?team_id=${teamId.value}`,
    )
    await Promise.all([fetchRoster(), fetchCostCheck()])
  } catch (error) {
    console.error('Error removing player:', error)
  }
}

defineExpose({ fetchRoster, fetchCostCheck, firstSquadPlayers, secondSquadPlayers, costCheck })
</script>
