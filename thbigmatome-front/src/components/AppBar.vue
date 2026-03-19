<template>
  <v-app-bar color="primary" elevation="2" :height="64">
    <v-app-bar-nav-icon @click.stop="emit('toggle-drawer')" />

    <v-app-bar-title @click="router.push('/')" style="cursor: pointer">
      <v-icon start>mdi-baseball</v-icon>
      THBIG Dugout
    </v-app-bar-title>

    <v-spacer />

    <v-btn icon variant="text" @click="toggleTheme">
      <v-icon>{{ isDark ? 'mdi-weather-sunny' : 'mdi-weather-night' }}</v-icon>
    </v-btn>

    <v-menu>
      <template v-slot:activator="{ props }">
        <v-btn v-bind="props" icon="mdi-account-circle" variant="text" />
      </template>

      <v-list>
        <v-list-item>
          <v-list-item-title>{{ user?.name }}</v-list-item-title>
        </v-list-item>

        <v-divider />

        <v-list-item :to="{ path: '/settings', query: { tab: 'account' } }">
          <v-list-item-title>
            <v-icon start>mdi-lock-reset</v-icon>
            パスワード変更
          </v-list-item-title>
        </v-list-item>

        <v-list-item @click="handleLogout">
          <v-list-item-title>
            <v-icon start>mdi-logout</v-icon>
            ログアウト
          </v-list-item-title>
        </v-list-item>
      </v-list>
    </v-menu>
  </v-app-bar>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useTheme } from 'vuetify'
import { useAuth } from '@/composables/useAuth'

const emit = defineEmits<{
  'toggle-drawer': []
}>()

const router = useRouter()
const { user, logout } = useAuth()
const theme = useTheme()

const isDark = computed(() => theme.global.current.value.dark)

const toggleTheme = () => {
  const newTheme = theme.global.current.value.dark ? 'light' : 'dark'
  theme.change(newTheme)
  localStorage.setItem('theme', newTheme)
}

const handleLogout = async () => {
  await logout()
  router.push('/login')
}
</script>
