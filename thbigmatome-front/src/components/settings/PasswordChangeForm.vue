<template>
  <DataCard title="パスワード変更">
    <v-form ref="formRef" @submit.prevent="handleSubmit">
      <v-text-field
        v-model="currentPassword"
        label="現在のパスワード"
        type="password"
        :rules="[rules.required]"
        :error-messages="serverError ? [serverError] : []"
        variant="outlined"
        density="compact"
        class="mb-3"
      />
      <v-text-field
        v-model="newPassword"
        label="新しいパスワード"
        type="password"
        :rules="[rules.required, rules.notSameAsCurrent]"
        variant="outlined"
        density="compact"
        class="mb-3"
      />
      <v-text-field
        v-model="confirmPassword"
        label="確認用パスワード"
        type="password"
        :rules="[rules.required, rules.matches]"
        variant="outlined"
        density="compact"
        class="mb-4"
      />
      <v-btn type="submit" color="primary" :loading="loading">変更する</v-btn>
    </v-form>
  </DataCard>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import axios from '@/plugins/axios'
import DataCard from '@/components/shared/DataCard.vue'
import { useSnackbar } from '@/composables/useSnackbar'

const { showSnackbar } = useSnackbar()

const formRef = ref<{ validate: () => Promise<{ valid: boolean }> } | null>(null)
const currentPassword = ref('')
const newPassword = ref('')
const confirmPassword = ref('')
const loading = ref(false)
const serverError = ref('')

const rules = {
  required: (v: string) => !!v || '必須項目です',
  notSameAsCurrent: (v: string) =>
    v !== currentPassword.value || '新しいパスワードは現在のパスワードと異なる必要があります',
  matches: (v: string) => v === newPassword.value || 'パスワードが一致しません',
}

defineExpose({
  currentPassword,
  newPassword,
  confirmPassword,
  serverError,
  handleSubmit,
  callChangePassword,
})

async function callChangePassword() {
  loading.value = true
  try {
    await axios.post('/users/change_password', {
      current_password: currentPassword.value,
      password: newPassword.value,
      password_confirmation: confirmPassword.value,
    })
    showSnackbar('パスワードを変更しました', 'success')
    currentPassword.value = ''
    newPassword.value = ''
    confirmPassword.value = ''
  } catch (error: unknown) {
    const err = error as { response?: { data?: { error?: string; errors?: string[] } } }
    if (err.response?.data?.error) {
      serverError.value = err.response.data.error
    } else if (err.response?.data?.errors?.length) {
      showSnackbar(err.response.data.errors[0], 'error')
    } else {
      showSnackbar('パスワード変更に失敗しました', 'error')
    }
  } finally {
    loading.value = false
  }
}

async function handleSubmit() {
  serverError.value = ''
  const { valid } = await formRef.value!.validate()
  if (!valid) return
  await callChangePassword()
}
</script>
