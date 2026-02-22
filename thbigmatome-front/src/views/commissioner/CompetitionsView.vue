<template>
  <v-container>
    <v-row>
      <v-col cols="12">
        <h1 class="text-h4">大会管理</h1>
      </v-col>
    </v-row>

    <v-row>
      <v-col cols="12">
        <v-card>
          <v-card-title class="d-flex align-center">
            大会一覧
            <v-spacer></v-spacer>
            <v-btn color="primary" @click="openCreateDialog">新規大会作成</v-btn>
          </v-card-title>
          <v-card-text>
            <v-alert
              v-if="errorMessage"
              type="error"
              variant="tonal"
              class="mb-3"
              closable
              @click:close="errorMessage = ''"
            >
              {{ errorMessage }}
            </v-alert>
            <v-data-table
              :headers="headers"
              :items="competitions"
              :loading="loading"
              class="elevation-1"
              density="compact"
            >
              <template v-slot:[`item.actions`]="{ item }">
                <v-icon size="small" @click="openEditDialog(item)" title="編集">mdi-pencil</v-icon>
                <v-icon size="small" @click="deleteCompetition(item)" title="削除" class="ml-1"
                  >mdi-delete</v-icon
                >
                <v-icon
                  size="small"
                  class="ml-1"
                  title="ロスター管理"
                  @click="$router.push(`/competitions/${item.id}/roster`)"
                  >mdi-clipboard-list</v-icon
                >
              </template>
            </v-data-table>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- 新規大会作成ダイアログ -->
    <v-dialog v-model="createDialog" max-width="500px">
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
          <v-btn color="blue darken-1" text @click="closeCreateDialog">キャンセル</v-btn>
          <v-btn color="blue darken-1" text @click="createCompetition" :loading="creating"
            >作成</v-btn
          >
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 編集ダイアログ -->
    <v-dialog v-model="editDialog" max-width="500px">
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
          <v-btn color="blue darken-1" text @click="closeEditDialog">キャンセル</v-btn>
          <v-btn color="blue darken-1" text @click="updateCompetition" :loading="updating"
            >更新</v-btn
          >
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'
import { useSnackbar } from '@/composables/useSnackbar'

interface Competition {
  id: number
  name: string
  year: number
  competition_type: string
  entry_count: number
}

const { showSnackbar } = useSnackbar()

const competitions = ref<Competition[]>([])
const loading = ref(false)
const errorMessage = ref('')

const createDialog = ref(false)
const creating = ref(false)
const newCompetition = ref({ name: '', year: new Date().getFullYear(), competition_type: '' })

const editDialog = ref(false)
const updating = ref(false)
const editTarget = ref<Partial<Competition>>({})

const headers = [
  { title: 'ID', key: 'id', width: '80px' },
  { title: '大会名', key: 'name' },
  { title: '年度', key: 'year', width: '100px' },
  { title: '種別', key: 'competition_type' },
  { title: '参加数', key: 'entry_count', width: '100px' },
  { title: '操作', key: 'actions', sortable: false, width: '100px' },
]

onMounted(fetchCompetitions)

async function fetchCompetitions() {
  loading.value = true
  try {
    const response = await axios.get<Competition[]>('/competitions')
    competitions.value = response.data
  } catch (error) {
    errorMessage.value = '大会の取得に失敗しました'
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
    errorMessage.value = '大会の作成に失敗しました'
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
    errorMessage.value = '大会の更新に失敗しました'
    showSnackbar('大会の更新に失敗しました', 'error')
    console.error('Error updating competition:', error)
  } finally {
    updating.value = false
  }
}

async function deleteCompetition(competition: Competition) {
  if (!confirm(`「${competition.name}」を削除しますか？`)) return
  try {
    await axios.delete(`/competitions/${competition.id}`)
    competitions.value = competitions.value.filter((c) => c.id !== competition.id)
    showSnackbar('大会を削除しました', 'success')
  } catch (error) {
    errorMessage.value = '大会の削除に失敗しました'
    showSnackbar('大会の削除に失敗しました', 'error')
    console.error('Error deleting competition:', error)
  }
}
</script>
