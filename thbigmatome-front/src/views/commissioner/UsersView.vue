<template>
  <PageLayout>
    <template #filters>
      <v-text-field
        v-model="filterName"
        label="ユーザー名検索"
        prepend-inner-icon="mdi-magnify"
        density="compact"
        hide-details
        variant="outlined"
        clearable
        class="list-filter list-filter--search"
        data-testid="users-search"
      />
    </template>
    <template #actions>
      <v-btn color="action" variant="flat" prepend-icon="mdi-plus" @click="openCreateDialog">
        新規ユーザー作成
      </v-btn>
    </template>

    <AsyncState
      framed
      :loading="loading"
      :error="fetchFailed"
      error-message="ユーザーの取得に失敗しました"
      :empty="users.length === 0"
      empty-icon="mdi-account-off-outline"
      empty-message="ユーザーが登録されていません"
      @retry="fetchUsers"
    >
      <v-card>
        <v-data-table :headers="headers" :items="filteredUsers" class="ui-table" density="compact">
          <template v-slot:[`item.role`]="{ item }">
            <v-chip :color="item.role === 'commissioner' ? 'link' : 'default'" size="small">
              {{ item.role === 'commissioner' ? 'コミッショナー' : '一般' }}
            </v-chip>
          </template>
          <template v-slot:[`item.actions`]="{ item }">
            <div class="row-actions">
              <RowIconButton
                icon="mdi-account-edit-outline"
                :label="`${item.name}のロール変更`"
                @click="openRoleDialog(item)"
              />
              <RowIconButton
                icon="mdi-lock-reset"
                :label="`${item.name}のパスワードリセット`"
                @click="openResetDialog(item)"
              />
            </div>
          </template>
        </v-data-table>
      </v-card>
    </AsyncState>

    <!-- 新規ユーザー作成ダイアログ -->
    <v-dialog v-model="createDialog" max-width="500px" persistent>
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
          <v-btn variant="text" @click="closeCreateDialog">キャンセル</v-btn>
          <v-btn color="action" variant="flat" @click="createUser" :loading="creating">作成</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ロール変更ダイアログ -->
    <v-dialog v-model="roleDialog" max-width="400px" persistent>
      <v-card>
        <v-card-title>
          <span class="text-h5">ロール変更</span>
        </v-card-title>
        <v-card-text>
          <p class="mb-3 text-body-2">
            {{ roleTarget?.display_name || roleTarget?.name }} のロールを変更します。
          </p>
          <v-select
            v-model="newRole"
            :items="roleOptions"
            item-title="label"
            item-value="value"
            label="新しいロール"
            density="compact"
          ></v-select>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn variant="text" @click="closeRoleDialog">キャンセル</v-btn>
          <v-btn color="action" variant="flat" @click="submitRoleChange" :loading="roleChanging"
            >変更</v-btn
          >
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- パスワードリセットダイアログ -->
    <v-dialog v-model="resetDialog" max-width="400px" persistent>
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
          <v-btn variant="text" @click="closeResetDialog">キャンセル</v-btn>
          <v-btn color="action" variant="flat" @click="submitReset" :loading="resetting"
            >リセット</v-btn
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

interface User {
  id: number
  name: string
  display_name: string
  role: 'player' | 'commissioner'
}

const { showSnackbar } = useSnackbar()

const users = ref<User[]>([])
const loading = ref(true)
const fetchFailed = ref(false)
const filterName = ref('')

const filteredUsers = computed(() => {
  if (!filterName.value) return users.value
  const q = filterName.value.toLowerCase()
  return users.value.filter(
    (u) => u.name.toLowerCase().includes(q) || u.display_name.toLowerCase().includes(q),
  )
})

const createDialog = ref(false)
const creating = ref(false)
const createErrors = ref<string[]>([])
const newUser = ref({ name: '', display_name: '', password: '', role: 'player' })

const roleDialog = ref(false)
const roleChanging = ref(false)
const roleTarget = ref<User | null>(null)
const newRole = ref<'player' | 'commissioner'>('player')

const resetDialog = ref(false)
const resetting = ref(false)
const resetErrors = ref<string[]>([])
const resetTarget = ref<User | null>(null)
const newPassword = ref('')

const roleOptions = [
  { label: '一般', value: 'player' },
  { label: 'コミッショナー', value: 'commissioner' },
]

const headers = [
  { title: 'ID', key: 'id', width: '80px' },
  { title: 'ログインID', key: 'name' },
  { title: '表示名', key: 'display_name' },
  { title: 'ロール', key: 'role' },
  { title: '操作', key: 'actions', sortable: false, nowrap: true },
]

onMounted(fetchUsers)

async function fetchUsers() {
  loading.value = true
  fetchFailed.value = false
  try {
    const response = await axios.get<User[]>('/users')
    users.value = response.data
  } catch (error) {
    fetchFailed.value = true
    console.error('Error fetching users:', error)
  } finally {
    loading.value = false
  }
}

function openCreateDialog() {
  newUser.value = { name: '', display_name: '', password: '', role: 'player' }
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

function openRoleDialog(user: User) {
  roleTarget.value = user
  newRole.value = user.role
  roleDialog.value = true
}

function closeRoleDialog() {
  roleDialog.value = false
  roleTarget.value = null
}

async function submitRoleChange() {
  if (!roleTarget.value) return
  roleChanging.value = true
  try {
    const response = await axios.patch<User>(`/users/${roleTarget.value.id}/update_role`, {
      role: newRole.value,
    })
    const idx = users.value.findIndex((u) => u.id === roleTarget.value!.id)
    if (idx !== -1) users.value[idx] = response.data
    showSnackbar('ロールを変更しました', 'success')
    closeRoleDialog()
  } catch (error: unknown) {
    const data = (error as { response?: { data?: { error?: string } } })?.response?.data
    showSnackbar(data?.error ?? '変更できません', 'error')
  } finally {
    roleChanging.value = false
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
