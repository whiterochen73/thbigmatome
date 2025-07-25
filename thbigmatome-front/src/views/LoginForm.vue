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

        <button
          type="submit"
          :disabled="loading || !isFormValid"
          class="login-button"
        >
          {{ loading ? t('loginForm.loggingIn') : t('loginForm.login') }}
        </button>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useI18n } from 'vue-i18n'

const router = useRouter()
const { t } = useI18n()

const { login, loading } = useAuth()

const form = ref({
  loginName: '',
  password: ''
})

const error = ref('')

const isFormValid = computed(() => {
  return form.value.loginName.trim() !== '' && form.value.password.trim() !== ''
})

const handleLogin = async () => {
  error.value = ''

  try {
    await login(form.value.loginName, form.value.password)
    router.push('/menu') // ログイン成功後のリダイレクト先
  } catch (err: any) {
    error.value = err.message || t('loginForm.loginFailed')
  }
}
</script>

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background-color: #f5f5f5;
}

.login-card {
  background: white;
  padding: 2rem;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  width: 100%;
  max-width: 400px;
}

h2 {
  text-align: center;
  margin-bottom: 1.5rem;
  color: #333;
}

.form-group {
  margin-bottom: 1rem;
}

label {
  display: block;
  margin-bottom: 0.5rem;
  color: #555;
  font-weight: 500;
}

input {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
  transition: border-color 0.3s;
}

input:focus {
  outline: none;
  border-color: #007bff;
}

input:disabled {
  background-color: #f8f9fa;
  cursor: not-allowed;
}

.error-message {
  color: #dc3545;
  background-color: #f8d7da;
  border: 1px solid #f5c6cb;
  padding: 0.75rem;
  border-radius: 4px;
  margin-bottom: 1rem;
}

.login-button {
  width: 100%;
  padding: 0.75rem;
  background-color: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 1rem;
  cursor: pointer;
  transition: background-color 0.3s;
}

.login-button:hover:not(:disabled) {
  background-color: #0056b3;
}

.login-button:disabled {
  background-color: #6c757d;
  cursor: not-allowed;
}
</style>