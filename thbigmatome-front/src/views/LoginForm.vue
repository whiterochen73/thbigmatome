<template>
  <div class="login-container">
    <div class="login-card">
      <h2>{{ t('loginForm.title') }}</h2>
      <form @submit.prevent="handleLogin">
        <div class="form-group">
          <label for="loginName">{{ t('loginForm.loginId') }}</label>
          <input
            id="loginName"
            v-model="form.loginName"
            type="text"
            required
            :disabled="loading"
            :placeholder="t('loginForm.loginIdPlaceholder')"
          />
        </div>

        <div class="form-group">
          <label for="password">{{ t('loginForm.password') }}</label>
          <input
            id="password"
            v-model="form.password"
            type="password"
            required
            :disabled="loading"
            :placeholder="t('loginForm.passwordPlaceholder')"
          />
        </div>

        <div v-if="error" class="error-message">
          {{ error }}
        </div>

        <button type="submit" :disabled="loading || !isFormValid" class="login-button">
          {{ loading ? t('loginForm.loggingIn') : t('loginForm.login') }}
        </button>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { sanitizeRedirect } from '@/router/loginRedirect'
import { useAuth } from '@/composables/useAuth'
import { useI18n } from 'vue-i18n'

const router = useRouter()
const route = useRoute()
const { t } = useI18n()

const { login, loading } = useAuth()

const form = ref({
  loginName: '',
  password: '',
})

const error = ref('')

const isFormValid = computed(() => {
  return form.value.loginName.trim() !== '' && form.value.password.trim() !== ''
})

const handleLogin = async () => {
  error.value = ''

  try {
    await login(form.value.loginName, form.value.password)
    await nextTick() // リアクティビティ伝播を待つ
    // ログイン成功後は、セッション切れで離れた元の画面（redirect）へ戻る。無ければホーム
    router.push(sanitizeRedirect(route.query.redirect))
  } catch (err: unknown) {
    error.value = err instanceof Error ? err.message : t('loginForm.loginFailed')
  }
}
</script>

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background-color: rgb(var(--v-theme-background));
  color: rgb(var(--v-theme-on-surface));
}

.login-card {
  background: rgb(var(--v-theme-surface));
  color: rgb(var(--v-theme-on-surface));
  padding: 2rem;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  width: 100%;
  max-width: 400px;
}

h2 {
  text-align: center;
  margin-bottom: 1.5rem;
  color: rgb(var(--v-theme-on-surface));
}

.form-group {
  margin-bottom: 1rem;
}

label {
  display: block;
  margin-bottom: 0.5rem;
  color: rgb(var(--v-theme-on-surface-variant));
  font-weight: 500;
}

input {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid rgb(var(--v-theme-border-strong));
  background: rgb(var(--v-theme-surface));
  color: rgb(var(--v-theme-on-surface));
  border-radius: 4px;
  font-size: 1rem;
  transition: border-color 0.3s;
}

input:focus {
  outline: none;
  border-color: rgb(var(--v-theme-link));
}

input:disabled {
  background-color: rgb(var(--v-theme-surface-variant));
  cursor: not-allowed;
}

.error-message {
  color: rgb(var(--v-theme-on-state-warn));
  background-color: rgb(var(--v-theme-state-warn));
  border: 1px solid rgb(var(--v-theme-border-strong));
  padding: 0.75rem;
  border-radius: 4px;
  margin-bottom: 1rem;
}

.login-button {
  width: 100%;
  padding: 0.75rem;
  background-color: rgb(var(--v-theme-action));
  color: rgb(var(--v-theme-on-action));
  border: none;
  border-radius: 4px;
  font-size: 1rem;
  cursor: pointer;
  transition: background-color 0.3s;
}

.login-button:hover:not(:disabled) {
  background-color: rgb(var(--v-theme-action));
}

.login-button:disabled {
  background-color: rgb(var(--v-theme-surface-variant));
  color: rgb(var(--v-theme-on-surface-variant));
  cursor: not-allowed;
}
</style>
