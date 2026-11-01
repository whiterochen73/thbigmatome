<template>
  <PageLayout>
    <template #filters>
      <v-text-field
        v-model="filterName"
        label="球場名検索"
        prepend-inner-icon="mdi-magnify"
        density="compact"
        hide-details
        variant="outlined"
        clearable
        class="list-filter list-filter--search"
        data-testid="stadiums-search"
      />
    </template>
    <template #actions>
      <v-btn color="action" variant="flat" prepend-icon="mdi-plus" @click="openCreateDialog">
        新規球場作成
      </v-btn>
    </template>

    <AsyncState
      framed
      :loading="loading"
      :error="fetchFailed"
      error-message="球場の取得に失敗しました"
      :empty="stadiums.length === 0"
      empty-icon="mdi-stadium-outline"
      empty-message="球場が登録されていません"
      @retry="fetchStadiums"
    >
      <v-card>
        <v-data-table
          :headers="headers"
          :items="filteredStadiums"
          class="ui-table"
          density="compact"
        >
          <template v-slot:[`item.indoor`]="{ item }">
            {{ item.indoor ? '屋内' : '屋外' }}
          </template>
          <template v-slot:[`item.actions`]="{ item }">
            <RowIconButton
              icon="mdi-pencil"
              :label="`${item.name}を編集`"
              @click="openEditDialog(item)"
            />
          </template>
        </v-data-table>
      </v-card>
    </AsyncState>

    <!-- 新規球場作成ダイアログ -->
    <v-dialog v-model="createDialog" max-width="500px" persistent>
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
          <v-btn variant="text" @click="closeCreateDialog">キャンセル</v-btn>
          <v-btn color="action" variant="flat" @click="createStadium" :loading="creating"
            >作成</v-btn
          >
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 球場編集ダイアログ -->
    <v-dialog v-model="editDialog" max-width="500px" persistent>
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
          <v-btn variant="text" @click="closeEditDialog">キャンセル</v-btn>
          <v-btn color="action" variant="flat" @click="updateStadium" :loading="updating"
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
import { useSnackbar } from '@/composables/useSnackbar'
import AsyncState from '@/components/shared/AsyncState.vue'
import PageLayout from '@/components/shared/PageLayout.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'

interface Stadium {
  id: number
  name: string
  code: string
  indoor: boolean
  up_table_ids: number[]
}

const { showSnackbar } = useSnackbar()

const stadiums = ref<Stadium[]>([])
const loading = ref(true)
const fetchFailed = ref(false)
const filterName = ref('')

const filteredStadiums = computed(() => {
  if (!filterName.value) return stadiums.value
  const q = filterName.value.toLowerCase()
  return stadiums.value.filter((s) => s.name.toLowerCase().includes(q))
})

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
  fetchFailed.value = false
  try {
    const response = await axios.get<Stadium[]>('/stadiums')
    stadiums.value = response.data
  } catch (error) {
    fetchFailed.value = true
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
