<template>
  <v-dialog v-model="isOpen" max-width="500px" persistent>
    <v-card>
      <v-card-title>
        <span class="text-h5">{{
          isNew ? t('managerDialog.title.add') : t('managerDialog.title.edit')
        }}</span>
      </v-card-title>

      <v-card-text>
        <v-container>
          <v-row>
            <v-col cols="12">
              <v-text-field
                v-model="editedManager.name"
                :label="t('managerDialog.form.name')"
                :rules="[rules.required]"
                required
              ></v-text-field>
            </v-col>
            <v-col cols="12">
              <v-text-field
                v-model="editedManager.short_name"
                :label="t('managerDialog.form.shortName')"
                required
              ></v-text-field>
            </v-col>
            <v-col cols="12">
              <v-text-field
                v-model="editedManager.irc_name"
                :label="t('managerDialog.form.ircName')"
                required
              ></v-text-field>
            </v-col>
            <v-col cols="12">
              <v-text-field
                v-model="editedManager.user_id"
                :label="t('managerDialog.form.userId')"
              ></v-text-field>
            </v-col>
          </v-row>
        </v-container>
      </v-card-text>

      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn variant="text" @click="close">
          {{ t('actions.cancel') }}
        </v-btn>
        <v-btn color="accent" variant="flat" @click="save" :disabled="!isFormValid">
          {{ t('actions.save') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script lang="ts" setup>
import { ref, watch, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import { type Manager } from '@/types/manager'

const { t } = useI18n()
const { showSnackbar } = useSnackbar()

interface Props {
  manager: Manager | null // 編集対象のManagerデータ (新規作成の場合はnull)
}

// Propsの定義
const props = defineProps<Props>()

// Emitsの定義
const emit = defineEmits(['save'])

const isOpen = defineModel<boolean>({ default: false })

// 編集中のManagerデータ
const defaultManager: Manager = {
  id: 0,
  name: '',
  short_name: '',
  irc_name: '',
  user_id: null,
  role: 'director',
} // 新規作成時の初期値
const editedManager = ref<Manager>({ ...defaultManager })

// 新規作成かどうかの判定
const isNew = computed(() => !editedManager.value.id)

// バリデーションルール
const rules = {
  required: (value: string) => !!value || t('managerDialog.validation.required'),
}

// フォームの入力値が有効かどうかの判定 (今回は名前のみチェック)
const isFormValid = computed(() => !!editedManager.value.name)

watch(isOpen, (newVal) => {
  if (newVal) {
    editedManager.value = props.manager ? { ...props.manager } : { ...defaultManager }
  }
})

/**
 * ダイアログを閉じる
 */
const close = () => {
  isOpen.value = false
}

/**
 * Managerデータを保存する (新規作成または更新)
 */
const save = async () => {
  if (!isFormValid.value) return // バリデーションが通らなければ何もしない

  try {
    if (isNew.value) {
      // 新規作成
      await axios.post('/managers', { manager: editedManager.value })
      showSnackbar(t('managerDialog.notifications.addSuccess'), 'success')
    } else {
      // 更新
      await axios.patch(`/managers/${editedManager.value.id}`, { manager: editedManager.value })
      showSnackbar(t('managerDialog.notifications.updateSuccess'), 'success')
    }
    emit('save') // 親コンポーネントに保存が完了したことを通知 (一覧の再取得など)
    close() // ダイアログを閉じる
  } catch (error: unknown) {
    console.error('Error saving manager:', error)
    // エラーレスポンスがあれば表示
    const axiosError = error as { response?: { data?: { errors?: Record<string, string[]> } } }
    if (axiosError.response?.data?.errors) {
      const errorMessages = Object.values(axiosError.response.data.errors).flat().join('\n')
      showSnackbar(
        t('managerDialog.notifications.saveFailedWithErrors', { errors: errorMessages }),
        'error',
      )
    } else {
      showSnackbar(t('managerDialog.notifications.saveFailed'), 'error')
    }
  }
}
</script>
