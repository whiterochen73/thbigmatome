<template>
  <v-container>
    <v-row>
      <v-col cols="12">
        <h1 class="text-h4">リーグ管理</h1>
      </v-col>
    </v-row>

    <v-row>
      <v-col cols="12">
        <v-card>
          <v-card-title class="d-flex align-center">
            リーグ一覧
            <v-spacer></v-spacer>
            <v-btn color="primary" @click="openCreateDialog">新規リーグ作成</v-btn>
          </v-card-title>
          <v-card-text>
            <v-data-table
              :headers="headers"
              :items="leagues"
              :loading="loading"
              class="elevation-1"
            >
              <template v-slot:[`item.actions`]="{ item }">
                <v-icon small class="mr-2" @click="openMembershipDialog(item)"
                  >mdi-account-group</v-icon
                >
                <v-icon small class="mr-2" @click="openLeagueDetail(item)">mdi-cog</v-icon>
                <v-icon small class="mr-2" @click="editLeague(item)">mdi-pencil</v-icon>
                <v-icon small @click="deleteLeague(item)">mdi-delete</v-icon>
              </template>
            </v-data-table>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- リーグ作成/編集ダイアログ -->
    <v-dialog v-model="dialog" max-width="600px">
      <v-card>
        <v-card-title>
          <span class="text-h5">{{ formTitle }}</span>
        </v-card-title>
        <v-card-text>
          <v-container>
            <v-row>
              <v-col cols="12">
                <v-text-field v-model="editedLeague.name" label="リーグ名"></v-text-field>
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field
                  v-model.number="editedLeague.num_teams"
                  label="チーム数"
                  type="number"
                ></v-text-field>
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field
                  v-model.number="editedLeague.num_games"
                  label="試合数"
                  type="number"
                ></v-text-field>
              </v-col>
              <v-col cols="12">
                <v-checkbox v-model="editedLeague.active" label="アクティブ"></v-checkbox>
              </v-col>
            </v-row>
          </v-container>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn color="blue darken-1" text @click="closeDialog">キャンセル</v-btn>
          <v-btn color="blue darken-1" text @click="saveLeague">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- リーグ詳細パネル -->
    <v-row v-if="detailLeague">
      <v-col cols="12">
        <v-card>
          <v-card-title class="d-flex align-center">
            {{ detailLeague.name }} - {{ $t('commissioner.detail.title') }}
            <v-spacer></v-spacer>
            <v-btn icon size="small" @click="closeLeagueDetail">
              <v-icon>mdi-close</v-icon>
            </v-btn>
          </v-card-title>
          <v-card-text>
            <v-tabs v-model="detailTab">
              <v-tab value="seasons">{{ $t('commissioner.detail.tabs.seasons') }}</v-tab>
              <v-tab value="games">{{ $t('commissioner.detail.tabs.games') }}</v-tab>
              <v-tab value="poolPlayers">{{ $t('commissioner.detail.tabs.poolPlayers') }}</v-tab>
              <v-tab value="teamStaff">{{ $t('commissioner.detail.tabs.teamStaff') }}</v-tab>
              <v-tab value="absences">{{ $t('commissioner.detail.tabs.absences') }}</v-tab>
            </v-tabs>

            <v-tabs-window v-model="detailTab">
              <!-- シーズン管理 -->
              <v-tabs-window-item value="seasons">
                <v-alert type="info" variant="tonal" class="mt-4">
                  {{ $t('commissioner.detail.comingSoon') }}
                </v-alert>
              </v-tabs-window-item>

              <!-- 対戦管理 -->
              <v-tabs-window-item value="games">
                <v-alert type="info" variant="tonal" class="mt-4">
                  {{ $t('commissioner.detail.comingSoon') }}
                </v-alert>
              </v-tabs-window-item>

              <!-- 選手プール管理 -->
              <v-tabs-window-item value="poolPlayers">
                <v-alert type="info" variant="tonal" class="mt-4">
                  {{ $t('commissioner.detail.comingSoon') }}
                </v-alert>
              </v-tabs-window-item>

              <!-- チームスタッフ管理 -->
              <v-tabs-window-item value="teamStaff">
                <div class="mt-4">
                  <v-select
                    v-model="selectedStaffTeamId"
                    :items="detailLeagueTeams"
                    item-title="team.name"
                    item-value="team.id"
                    :label="$t('commissioner.detail.selectTeam')"
                    clearable
                    @update:model-value="onStaffTeamSelected"
                  ></v-select>
                  <v-data-table
                    v-if="selectedStaffTeamId"
                    :headers="teamManagerHeaders"
                    :items="teamManagers"
                    :loading="teamManagersLoading"
                    class="elevation-1"
                  >
                    <template v-slot:no-data>
                      {{ $t('commissioner.detail.teamStaffNoData') }}
                    </template>
                  </v-data-table>
                </div>
              </v-tabs-window-item>

              <!-- 選手離脱管理 -->
              <v-tabs-window-item value="absences">
                <v-alert type="info" variant="tonal" class="mt-4">
                  {{ $t('commissioner.detail.comingSoon') }}
                </v-alert>
              </v-tabs-window-item>
            </v-tabs-window>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- チームメンバーシップ管理ダイアログ -->
    <v-dialog v-model="membershipDialog" max-width="800px">
      <v-card>
        <v-card-title>
          <span class="text-h5">{{ selectedLeagueName }} のチーム管理</span>
        </v-card-title>
        <v-card-text>
          <v-container>
            <v-row>
              <v-col cols="12">
                <v-select
                  v-model="selectedTeamIdToAdd"
                  :items="availableTeams"
                  item-title="name"
                  item-value="id"
                  label="追加するチーム"
                  clearable
                ></v-select>
                <v-btn color="primary" @click="addTeamToLeague" :disabled="!selectedTeamIdToAdd"
                  >チームを追加</v-btn
                >
              </v-col>
            </v-row>
            <v-row>
              <v-col cols="12">
                <v-data-table
                  :headers="membershipHeaders"
                  :items="currentLeagueTeams"
                  :loading="membershipLoading"
                  class="elevation-1"
                >
                  <template v-slot:[`item.actions`]="{ item }">
                    <v-icon small @click="removeTeamFromLeague(item)">mdi-delete</v-icon>
                  </template>
                </v-data-table>
              </v-col>
            </v-row>
          </v-container>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn color="blue darken-1" text @click="closeMembershipDialog">閉じる</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import axios from 'axios'
import { useSnackbar } from '@/composables/useSnackbar'

interface League {
  id?: number
  name: string
  num_teams: number
  num_games: number
  active: boolean
}

interface Team {
  id: number
  name: string
}

interface LeagueMembership {
  id: number
  team: Team
}

interface TeamManager {
  id: number
  team_id: number
  manager_id: number
  role: string
  manager: {
    id: number
    name: string
  }
}

const { showSnackbar } = useSnackbar()

const leagues = ref<League[]>([])
const loading = ref(false)
const dialog = ref(false)
const editedLeague = ref<League>({ name: '', num_teams: 6, num_games: 30, active: false })
const defaultLeague = { name: '', num_teams: 6, num_games: 30, active: false }
const editedIndex = ref(-1)

const membershipDialog = ref(false)
const selectedLeagueId = ref<number | null>(null)
const selectedLeagueName = ref<string>('')
const currentLeagueTeams = ref<LeagueMembership[]>([])
const availableTeams = ref<Team[]>([])
const selectedTeamIdToAdd = ref<number | null>(null)
const membershipLoading = ref(false)

const headers = [
  { title: 'ID', key: 'id' },
  { title: 'リーグ名', key: 'name' },
  { title: 'チーム数', key: 'num_teams' },
  { title: '試合数', key: 'num_games' },
  { title: 'アクティブ', key: 'active' },
  { title: '操作', key: 'actions', sortable: false },
]

const membershipHeaders = [
  { title: 'チーム名', key: 'team.name' },
  { title: '操作', key: 'actions', sortable: false },
]

// リーグ詳細パネル
const detailLeague = ref<League | null>(null)
const detailTab = ref('seasons')
const detailLeagueTeams = ref<LeagueMembership[]>([])

// チームスタッフ管理
const selectedStaffTeamId = ref<number | null>(null)
const teamManagers = ref<TeamManager[]>([])
const teamManagersLoading = ref(false)
const teamManagerHeaders = [
  { title: '監督名', key: 'manager.name' },
  { title: '役割', key: 'role' },
]

const formTitle = computed(() => (editedIndex.value === -1 ? '新規リーグ作成' : 'リーグ編集'))

onMounted(fetchLeagues)

async function fetchLeagues() {
  loading.value = true
  try {
    const response = await axios.get<League[]>('/commissioner/leagues')
    leagues.value = response.data
  } catch (error) {
    showSnackbar('リーグの取得に失敗しました', 'error')
    console.error('Error fetching leagues:', error)
  } finally {
    loading.value = false
  }
}

function openCreateDialog() {
  editedLeague.value = { ...defaultLeague }
  editedIndex.value = -1
  dialog.value = true
}

function editLeague(item: League) {
  editedLeague.value = { ...item }
  editedIndex.value = leagues.value.indexOf(item)
  dialog.value = true
}

async function saveLeague() {
  try {
    if (editedIndex.value > -1) {
      // 更新
      const response = await axios.put<League>(
        `/commissioner/leagues/${editedLeague.value.id}`,
        editedLeague.value,
      )
      Object.assign(leagues.value[editedIndex.value], response.data)
      showSnackbar('リーグを更新しました', 'success')
    } else {
      // 新規作成
      const response = await axios.post<League>('/commissioner/leagues', editedLeague.value)
      leagues.value.push(response.data)
      showSnackbar('リーグを作成しました', 'success')
    }
    closeDialog()
  } catch (error) {
    showSnackbar('リーグの保存に失敗しました', 'error')
    console.error('Error saving league:', error)
  }
}

async function deleteLeague(item: League) {
  if (confirm(`リーグ「${item.name}」を削除してもよろしいですか？`)) {
    try {
      await axios.delete(`/commissioner/leagues/${item.id}`)
      leagues.value = leagues.value.filter((league) => league.id !== item.id)
      showSnackbar('リーグを削除しました', 'success')
    } catch (error) {
      showSnackbar('リーグの削除に失敗しました', 'error')
      console.error('Error deleting league:', error)
    }
  }
}

function closeDialog() {
  dialog.value = false
  editedLeague.value = { ...defaultLeague }
  editedIndex.value = -1
}

// チームメンバーシップ関連の関数
async function openMembershipDialog(league: League) {
  selectedLeagueId.value = league.id || null
  selectedLeagueName.value = league.name
  membershipDialog.value = true
  await fetchLeagueTeams()
  await fetchAvailableTeams()
}

async function fetchLeagueTeams() {
  if (!selectedLeagueId.value) return
  membershipLoading.value = true
  try {
    const response = await axios.get<LeagueMembership[]>(
      `/commissioner/leagues/${selectedLeagueId.value}/league_memberships`,
    )
    currentLeagueTeams.value = response.data
  } catch (error) {
    showSnackbar('リーグチームの取得に失敗しました', 'error')
    console.error('Error fetching league teams:', error)
  } finally {
    membershipLoading.value = false
  }
}

async function fetchAvailableTeams() {
  try {
    const response = await axios.get<Team[]>('/teams')
    // 既にリーグに所属しているチームを除外
    const currentTeamIds = new Set(currentLeagueTeams.value.map((lm) => lm.team.id))
    availableTeams.value = response.data.filter((team) => !currentTeamIds.has(team.id))
  } catch (error) {
    showSnackbar('利用可能なチームの取得に失敗しました', 'error')
    console.error('Error fetching available teams:', error)
  }
}

async function addTeamToLeague() {
  if (!selectedLeagueId.value || !selectedTeamIdToAdd.value) return
  try {
    await axios.post(`/commissioner/leagues/${selectedLeagueId.value}/league_memberships`, {
      league_membership: { team_id: selectedTeamIdToAdd.value },
    })
    showSnackbar('チームをリーグに追加しました', 'success')
    selectedTeamIdToAdd.value = null
    await fetchLeagueTeams()
    await fetchAvailableTeams()
  } catch (error) {
    showSnackbar('チームの追加に失敗しました', 'error')
    console.error('Error adding team to league:', error)
  }
}

async function removeTeamFromLeague(item: LeagueMembership) {
  if (!selectedLeagueId.value || !item.id) return
  if (confirm(`リーグからチーム「${item.team.name}」を削除してもよろしいですか？`)) {
    try {
      await axios.delete(
        `/commissioner/leagues/${selectedLeagueId.value}/league_memberships/${item.id}`,
      )
      showSnackbar('チームをリーグから削除しました', 'success')
      await fetchLeagueTeams()
      await fetchAvailableTeams()
    } catch (error) {
      showSnackbar('チームの削除に失敗しました', 'error')
      console.error('Error removing team from league:', error)
    }
  }
}

function closeMembershipDialog() {
  membershipDialog.value = false
  selectedLeagueId.value = null
  selectedLeagueName.value = ''
  currentLeagueTeams.value = []
  availableTeams.value = []
  selectedTeamIdToAdd.value = null
}

// リーグ詳細パネル関連
async function openLeagueDetail(league: League) {
  detailLeague.value = league
  detailTab.value = 'seasons'
  selectedStaffTeamId.value = null
  teamManagers.value = []
  await fetchDetailLeagueTeams(league.id!)
}

function closeLeagueDetail() {
  detailLeague.value = null
  detailLeagueTeams.value = []
  selectedStaffTeamId.value = null
  teamManagers.value = []
}

async function fetchDetailLeagueTeams(leagueId: number) {
  try {
    const response = await axios.get<LeagueMembership[]>(
      `/commissioner/leagues/${leagueId}/league_memberships`,
    )
    detailLeagueTeams.value = response.data
  } catch (error) {
    console.error('Error fetching detail league teams:', error)
  }
}

async function onStaffTeamSelected(teamId: number | null) {
  teamManagers.value = []
  if (!teamId || !detailLeague.value?.id) return
  await fetchTeamManagers(detailLeague.value.id, teamId)
}

async function fetchTeamManagers(leagueId: number, teamId: number) {
  teamManagersLoading.value = true
  try {
    const response = await axios.get<TeamManager[]>(
      `/commissioner/leagues/${leagueId}/teams/${teamId}/team_managers`,
    )
    teamManagers.value = response.data
  } catch (error) {
    showSnackbar('チームスタッフの取得に失敗しました', 'error')
    console.error('Error fetching team managers:', error)
  } finally {
    teamManagersLoading.value = false
  }
}
</script>
