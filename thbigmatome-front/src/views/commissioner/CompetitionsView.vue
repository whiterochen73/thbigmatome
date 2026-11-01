<template>
  <PageLayout>
    <template #filters>
      <v-text-field
        v-model="filterName"
        label="大会名検索"
        prepend-inner-icon="mdi-magnify"
        density="compact"
        hide-details
        variant="outlined"
        clearable
        class="list-filter list-filter--search"
        data-testid="competitions-search"
      />
    </template>
    <template #actions>
      <v-btn color="action" variant="flat" prepend-icon="mdi-plus" @click="openCreateDialog">
        新規大会作成
      </v-btn>
    </template>

    <AsyncState
      framed
      :loading="loading"
      :error="fetchFailed"
      error-message="大会の取得に失敗しました"
      :empty="competitions.length === 0"
      empty-icon="mdi-trophy-outline"
      empty-message="大会が登録されていません"
      @retry="fetchCompetitions"
    >
      <v-card>
        <v-data-table
          :headers="headers"
          :items="filteredCompetitions"
          class="ui-table ui-table--rows"
          density="compact"
          mobile-breakpoint="sm"
        >
          <template v-slot:[`item.actions`]="{ item }">
            <div class="row-actions row-actions--full">
              <RowIconButton
                icon="mdi-pencil"
                :label="`${item.name}を編集`"
                @click="openEditDialog(item)"
              />
              <RowIconButton
                icon="mdi-clipboard-list-outline"
                :label="`${item.name}のロスター管理`"
                @click="openRoster(item)"
              />
              <RowIconButton
                icon="mdi-delete-outline"
                danger
                :label="`${item.name}を削除`"
                @click="deleteCompetition(item)"
              />
            </div>
            <RowMenu
              :label="`${item.name}の操作`"
              :items="[
                { icon: 'mdi-pencil', label: '編集', onClick: () => openEditDialog(item) },
                {
                  icon: 'mdi-clipboard-list-outline',
                  label: 'ロスター管理',
                  onClick: () => openRoster(item),
                },
                {
                  icon: 'mdi-delete-outline',
                  label: '削除',
                  danger: true,
                  onClick: () => deleteCompetition(item),
                },
              ]"
            />
          </template>
        </v-data-table>
      </v-card>
    </AsyncState>

    <!-- 新規大会作成ダイアログ -->
    <v-dialog v-model="createDialog" max-width="500px" persistent>
      <v-card>
        <v-card-title>
          <span class="text-h5">新規大会作成</span>
        </v-card-title>
        <v-card-text>
          <v-container>
            <v-row>
              <v-col cols="12">
                <v-text-field
                  v-model="newCompetition.name"
                  label="大会名"
                  density="compact"
                ></v-text-field>
              </v-col>
              <v-col cols="12">
                <v-text-field
                  v-model.number="newCompetition.year"
                  label="年度"
                  type="number"
                  density="compact"
                ></v-text-field>
              </v-col>
              <v-col cols="12">
                <v-text-field
                  v-model="newCompetition.competition_type"
                  label="種別"
                  density="compact"
                ></v-text-field>
              </v-col>
            </v-row>
          </v-container>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn variant="text" @click="closeCreateDialog">キャンセル</v-btn>
          <v-btn color="action" variant="flat" @click="createCompetition" :loading="creating"
            >作成</v-btn
          >
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 編集ダイアログ -->
    <v-dialog v-model="editDialog" max-width="500px" persistent>
      <v-card>
        <v-card-title>
          <span class="text-h5">大会編集</span>
        </v-card-title>
        <v-card-text>
          <v-container>
            <v-row>
              <v-col cols="12">
                <v-text-field
                  v-model="editTarget.name"
                  label="大会名"
                  density="compact"
                ></v-text-field>
              </v-col>
              <v-col cols="12">
                <v-text-field
                  v-model.number="editTarget.year"
                  label="年度"
                  type="number"
                  density="compact"
                ></v-text-field>
              </v-col>
              <v-col cols="12">
                <v-text-field
                  v-model="editTarget.competition_type"
                  label="種別"
                  density="compact"
                ></v-text-field>
              </v-col>
            </v-row>
          </v-container>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn variant="text" @click="closeEditDialog">キャンセル</v-btn>
          <v-btn color="action" variant="flat" @click="updateCompetition" :loading="updating"
            >更新</v-btn
          >
        </v-card-actions>
      </v-card>
    </v-dialog>
  </PageLayout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import axios from 'axios'
import { useRouter } from 'vue-router'
import { useSnackbar } from '@/composables/useSnackbar'
import AsyncState from '@/components/shared/AsyncState.vue'
import PageLayout from '@/components/shared/PageLayout.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'
import RowMenu from '@/components/shared/RowMenu.vue'
import { tableCell } from '@/components/shared/tableCells'

interface Competition {
  id: number
  name: string
  year: number
  competition_type: string
  entry_count: number
}

const router = useRouter()
const { showSnackbar } = useSnackbar()

const competitions = ref<Competition[]>([])
const userTeamId = ref<number | null>(null)
const loading = ref(true)
const fetchFailed = ref(false)
const filterName = ref('')

const filteredCompetitions = computed(() => {
  if (!filterName.value) return competitions.value
  const q = filterName.value.toLowerCase()
  return competitions.value.filter((c) => c.name.toLowerCase().includes(q))
})

const createDialog = ref(false)
const creating = ref(false)
const newCompetition = ref({ name: '', year: new Date().getFullYear(), competition_type: '' })

const editDialog = ref(false)
const updating = ref(false)
const editTarget = ref<Partial<Competition>>({})

const headers = [
  { title: 'ID', key: 'id', width: '80px', cellProps: tableCell.lead },
  { title: '大会名', key: 'name', cellProps: tableCell.title },
  { title: '年度', key: 'year', width: '100px', cellProps: tableCell.sub1 },
  { title: '種別', key: 'competition_type', cellProps: tableCell.sub2 },
  { title: '参加数', key: 'entry_count', width: '100px' },
  { title: '操作', key: 'actions', sortable: false, nowrap: true, cellProps: tableCell.act },
]

onMounted(async () => {
  await fetchCompetitions()
  try {
    const res = await axios.get<{ id: number }[]>('/teams')
    if (res.data.length > 0) userTeamId.value = res.data[0].id
  } catch {
    /* ignore */
  }
})

async function fetchCompetitions() {
  loading.value = true
  fetchFailed.value = false
  try {
    const response = await axios.get<Competition[]>('/competitions')
    competitions.value = response.data
  } catch (error) {
    fetchFailed.value = true
    console.error('Error fetching competitions:', error)
  } finally {
    loading.value = false
  }
}

function openCreateDialog() {
  newCompetition.value = { name: '', year: new Date().getFullYear(), competition_type: '' }
  createDialog.value = true
}

function closeCreateDialog() {
  createDialog.value = false
}

async function createCompetition() {
  creating.value = true
  try {
    const response = await axios.post<Competition>('/competitions', {
      competition: newCompetition.value,
    })
    competitions.value.push(response.data)
    showSnackbar('大会を作成しました', 'success')
    closeCreateDialog()
  } catch (error) {
    showSnackbar('大会の作成に失敗しました', 'error')
    console.error('Error creating competition:', error)
  } finally {
    creating.value = false
  }
}

function openEditDialog(competition: Competition) {
  editTarget.value = { ...competition }
  editDialog.value = true
}

function closeEditDialog() {
  editDialog.value = false
  editTarget.value = {}
}

async function updateCompetition() {
  if (!editTarget.value.id) return
  updating.value = true
  try {
    const response = await axios.patch<Competition>(`/competitions/${editTarget.value.id}`, {
      competition: editTarget.value,
    })
    const index = competitions.value.findIndex((c) => c.id === editTarget.value.id)
    if (index !== -1) {
      competitions.value[index] = response.data
    }
    showSnackbar('大会を更新しました', 'success')
    closeEditDialog()
  } catch (error) {
    showSnackbar('大会の更新に失敗しました', 'error')
    console.error('Error updating competition:', error)
  } finally {
    updating.value = false
  }
}

function openRoster(competition: Competition) {
  if (!userTeamId.value) return
  router.push({
    name: 'CompetitionRoster',
    params: { id: competition.id, teamId: userTeamId.value },
  })
}

async function deleteCompetition(competition: Competition) {
  if (!confirm(`「${competition.name}」を削除しますか？`)) return
  try {
    await axios.delete(`/competitions/${competition.id}`)
    competitions.value = competitions.value.filter((c) => c.id !== competition.id)
    showSnackbar('大会を削除しました', 'success')
  } catch (error) {
    showSnackbar('大会の削除に失敗しました', 'error')
    console.error('Error deleting competition:', error)
  }
}
</script>

<style scoped>
.list-filter--search {
  flex: 0 1 260px;
  min-width: 180px;
}

@media (max-width: 599.98px) {
  .list-filter--search {
    flex: 1 1 100%;
  }
}
</style>
