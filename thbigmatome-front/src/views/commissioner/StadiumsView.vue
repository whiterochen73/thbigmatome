<template>
  <v-container>
    <v-row>
      <v-col cols="12">
        <h1 class="text-h4">球場管理</h1>
      </v-col>
    </v-row>

    <v-row>
      <v-col cols="12">
        <v-card>
          <v-card-title class="d-flex align-center">
            球場一覧
            <v-spacer></v-spacer>
            <v-btn color="primary" @click="openCreateDialog">新規球場作成</v-btn>
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
              :items="stadiums"
              :loading="loading"
              class="elevation-1"
              density="compact"
            >
              <template v-slot:[`item.indoor`]="{ item }">
                {{ item.indoor ? '屋内' : '屋外' }}
              </template>
              <template v-slot:[`item.actions`]="{ item }">
                <v-icon size="small" @click="openEditDialog(item)" title="編集">mdi-pencil</v-icon>
              </template>
            </v-data-table>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- 新規球場作成ダイアログ -->
    <v-dialog v-model="createDialog" max-width="500px">
      <v-card>
        <v-card-title>
          <span class="text-h5">新規球場作成</span>
        </v-card-title>
        <v-card-text>
          <v-alert v-if="createErrors.length" type="error" variant="tonal" class="mb-3">
            <ul class="pl-4">
              <li v-for="err in createErrors" :key="err">{{ err }}</li>
            </ul>
          </v-alert>
          <v-container>
            <v-row>
              <v-col cols="12">
                <v-text-field
                  v-model="newStadium.name"
                  label="球場名"
                  density="compact"
                ></v-text-field>
              </v-col>
              <v-col cols="12">
                <v-text-field
                  v-model="newStadium.code"
                  label="球場コード"
                  density="compact"
                ></v-text-field>
              </v-col>
              <v-col cols="12">
                <v-checkbox v-model="newStadium.indoor" label="屋内"></v-checkbox>
              </v-col>
            </v-row>
          </v-container>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn color="blue darken-1" text @click="closeCreateDialog">キャンセル</v-btn>
          <v-btn color="blue darken-1" text @click="createStadium" :loading="creating">作成</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 球場編集ダイアログ -->
    <v-dialog v-model="editDialog" max-width="500px">
      <v-card>
        <v-card-title>
          <span class="text-h5">球場編集</span>
        </v-card-title>
        <v-card-text>
          <v-alert v-if="editErrors.length" type="error" variant="tonal" class="mb-3">
            <ul class="pl-4">
              <li v-for="err in editErrors" :key="err">{{ err }}</li>
            </ul>
          </v-alert>
          <v-container>
            <v-row>
              <v-col cols="12">
                <v-text-field
                  v-model="editForm.name"
                  label="球場名"
                  density="compact"
                ></v-text-field>
              </v-col>
              <v-col cols="12">
                <v-text-field
                  v-model="editForm.code"
                  label="球場コード"
                  density="compact"
                ></v-text-field>
              </v-col>
              <v-col cols="12">
                <v-checkbox v-model="editForm.indoor" label="屋内"></v-checkbox>
              </v-col>
            </v-row>
          </v-container>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn color="blue darken-1" text @click="closeEditDialog">キャンセル</v-btn>
          <v-btn color="blue darken-1" text @click="updateStadium" :loading="updating">更新</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'
import { useSnackbar } from '@/composables/useSnackbar'

interface Stadium {
  id: number
  name: string
  code: string
  indoor: boolean
  up_table_ids: number[]
}

const { showSnackbar } = useSnackbar()

const stadiums = ref<Stadium[]>([])
const loading = ref(false)
const errorMessage = ref('')

const createDialog = ref(false)
const creating = ref(false)
const createErrors = ref<string[]>([])
const newStadium = ref({ name: '', code: '', indoor: false })

const editDialog = ref(false)
const updating = ref(false)
const editErrors = ref<string[]>([])
const editTarget = ref<Stadium | null>(null)
const editForm = ref({ name: '', code: '', indoor: false })

const headers = [
  { title: 'ID', key: 'id', width: '80px' },
  { title: '球場名', key: 'name' },
  { title: 'コード', key: 'code' },
  { title: '屋内', key: 'indoor' },
  { title: '操作', key: 'actions', sortable: false, width: '80px' },
]

onMounted(fetchStadiums)

async function fetchStadiums() {
  loading.value = true
  try {
    const response = await axios.get<Stadium[]>('/stadiums')
    stadiums.value = response.data
  } catch (error) {
    errorMessage.value = '球場の取得に失敗しました'
    console.error('Error fetching stadiums:', error)
  } finally {
    loading.value = false
  }
}

function openCreateDialog() {
  newStadium.value = { name: '', code: '', indoor: false }
  createErrors.value = []
  createDialog.value = true
}

function closeCreateDialog() {
  createDialog.value = false
  createErrors.value = []
}

async function createStadium() {
  creating.value = true
  createErrors.value = []
  try {
    const response = await axios.post<Stadium>('/stadiums', { stadium: newStadium.value })
    stadiums.value.push(response.data)
    showSnackbar('球場を作成しました', 'success')
    closeCreateDialog()
  } catch (error: unknown) {
    const data = (error as { response?: { data?: { errors?: string[] } } })?.response?.data
    if (data?.errors) {
      createErrors.value = data.errors
    } else {
      createErrors.value = ['球場の作成に失敗しました']
    }
  } finally {
    creating.value = false
  }
}

function openEditDialog(stadium: Stadium) {
  editTarget.value = stadium
  editForm.value = { name: stadium.name, code: stadium.code, indoor: stadium.indoor }
  editErrors.value = []
  editDialog.value = true
}

function closeEditDialog() {
  editDialog.value = false
  editTarget.value = null
  editErrors.value = []
}

async function updateStadium() {
  if (!editTarget.value) return
  updating.value = true
  editErrors.value = []
  try {
    const response = await axios.patch<Stadium>(`/stadiums/${editTarget.value.id}`, {
      stadium: editForm.value,
    })
    const index = stadiums.value.findIndex((s) => s.id === editTarget.value!.id)
    if (index !== -1) {
      stadiums.value[index] = response.data
    }
    showSnackbar('球場を更新しました', 'success')
    closeEditDialog()
  } catch (error: unknown) {
    const data = (error as { response?: { data?: { errors?: string[] } } })?.response?.data
    if (data?.errors) {
      editErrors.value = data.errors
    } else {
      editErrors.value = ['球場の更新に失敗しました']
    }
  } finally {
    updating.value = false
  }
}
</script>
