<template>
  <v-container>
    <v-row>
      <v-col cols="12">
        <h1 class="text-h4">ユーザー管理</h1>
      </v-col>
    </v-row>

    <v-row>
      <v-col cols="12">
        <v-card>
          <v-card-title class="d-flex align-center">
            ユーザー一覧
            <v-spacer></v-spacer>
            <v-btn color="primary" @click="openCreateDialog">新規ユーザー作成</v-btn>
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
              :items="users"
              :loading="loading"
              class="elevation-1"
              density="compact"
            >
              <template v-slot:[`item.role`]="{ item }">
                <v-chip :color="item.role === 'commissioner' ? 'primary' : 'default'" size="small">
                  {{ item.role === 'commissioner' ? 'コミッショナー' : '一般' }}
                </v-chip>
              </template>
              <template v-slot:[`item.actions`]="{ item }">
                <v-icon size="small" @click="openResetDialog(item)" title="パスワードリセット"
                  >mdi-lock-reset</v-icon
                >
              </template>
            </v-data-table>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- 新規ユーザー作成ダイアログ -->
    <v-dialog v-model="createDialog" max-width="500px">
      <v-card>
        <v-card-title>
          <span class="text-h5">新規ユーザー作成</span>
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
                  v-model="newUser.name"
                  label="ログインID"
                  :error-messages="fieldError('name')"
                  density="compact"
                ></v-text-field>
              </v-col>
              <v-col cols="12">
                <v-text-field
                  v-model="newUser.display_name"
                  label="表示名"
                  density="compact"
                ></v-text-field>
              </v-col>
              <v-col cols="12">
                <v-text-field
                  v-model="newUser.password"
                  label="パスワード"
                  type="password"
                  density="compact"
                ></v-text-field>
              </v-col>
              <v-col cols="12">
                <v-select
                  v-model="newUser.role"
                  :items="roleOptions"
                  item-title="label"
                  item-value="value"
                  label="ロール"
                  density="compact"
                ></v-select>
              </v-col>
            </v-row>
          </v-container>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn color="blue darken-1" text @click="closeCreateDialog">キャンセル</v-btn>
          <v-btn color="blue darken-1" text @click="createUser" :loading="creating">作成</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- パスワードリセットダイアログ -->
    <v-dialog v-model="resetDialog" max-width="400px">
      <v-card>
        <v-card-title>
          <span class="text-h5">パスワードリセット</span>
        </v-card-title>
        <v-card-text>
          <p class="mb-3 text-body-2">{{ resetTarget?.name }} のパスワードをリセットします。</p>
          <v-alert v-if="resetErrors.length" type="error" variant="tonal" class="mb-3">
            <ul class="pl-4">
              <li v-for="err in resetErrors" :key="err">{{ err }}</li>
            </ul>
          </v-alert>
          <v-text-field
            v-model="newPassword"
            label="新しいパスワード"
            type="password"
            density="compact"
          ></v-text-field>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn color="blue darken-1" text @click="closeResetDialog">キャンセル</v-btn>
          <v-btn color="blue darken-1" text @click="submitReset" :loading="resetting"
            >リセット</v-btn
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

interface User {
  id: number
  name: string
  display_name: string
  role: 'general' | 'commissioner'
}

const { showSnackbar } = useSnackbar()

const users = ref<User[]>([])
const loading = ref(false)
const errorMessage = ref('')

const createDialog = ref(false)
const creating = ref(false)
const createErrors = ref<string[]>([])
const newUser = ref({ name: '', display_name: '', password: '', role: 'general' })

const resetDialog = ref(false)
const resetting = ref(false)
const resetErrors = ref<string[]>([])
const resetTarget = ref<User | null>(null)
const newPassword = ref('')

const roleOptions = [
  { label: '一般', value: 'general' },
  { label: 'コミッショナー', value: 'commissioner' },
]

const headers = [
  { title: 'ID', key: 'id', width: '80px' },
  { title: 'ログインID', key: 'name' },
  { title: '表示名', key: 'display_name' },
  { title: 'ロール', key: 'role' },
  { title: '操作', key: 'actions', sortable: false, width: '80px' },
]

onMounted(fetchUsers)

async function fetchUsers() {
  loading.value = true
  try {
    const response = await axios.get<User[]>('/users')
    users.value = response.data
  } catch (error) {
    errorMessage.value = 'ユーザーの取得に失敗しました'
    console.error('Error fetching users:', error)
  } finally {
    loading.value = false
  }
}

function openCreateDialog() {
  newUser.value = { name: '', display_name: '', password: '', role: 'general' }
  createErrors.value = []
  createDialog.value = true
}

function closeCreateDialog() {
  createDialog.value = false
  createErrors.value = []
}

function fieldError(field: string): string {
  const prefix = field === 'name' ? 'Name' : field
  const found = createErrors.value.find((e) => e.startsWith(prefix))
  return found || ''
}

async function createUser() {
  creating.value = true
  createErrors.value = []
  try {
    const response = await axios.post<User>('/users', { user: newUser.value })
    users.value.push(response.data)
    showSnackbar('ユーザーを作成しました', 'success')
    closeCreateDialog()
  } catch (error: unknown) {
    const data = (error as { response?: { data?: { errors?: string[] } } })?.response?.data
    if (data?.errors) {
      createErrors.value = data.errors
    } else {
      createErrors.value = ['ユーザーの作成に失敗しました']
    }
  } finally {
    creating.value = false
  }
}

function openResetDialog(user: User) {
  resetTarget.value = user
  newPassword.value = ''
  resetErrors.value = []
  resetDialog.value = true
}

function closeResetDialog() {
  resetDialog.value = false
  resetTarget.value = null
  newPassword.value = ''
  resetErrors.value = []
}

async function submitReset() {
  if (!resetTarget.value) return
  resetting.value = true
  resetErrors.value = []
  try {
    await axios.patch(`/users/${resetTarget.value.id}/reset_password`, {
      password: newPassword.value,
    })
    showSnackbar('パスワードをリセットしました', 'success')
    closeResetDialog()
  } catch (error: unknown) {
    const data = (error as { response?: { data?: { errors?: string[] } } })?.response?.data
    if (data?.errors) {
      resetErrors.value = data.errors
    } else {
      resetErrors.value = ['パスワードのリセットに失敗しました']
    }
  } finally {
    resetting.value = false
  }
}
</script>
