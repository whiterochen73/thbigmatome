<template>
  <v-app-bar color="primary" elevation="2" :height="64">
    <v-app-bar-nav-icon @click.stop="emit('toggle-drawer')" />

    <v-app-bar-title @click="router.push('/menu')" style="cursor: pointer">
      <v-icon start>mdi-baseball</v-icon>
      東方BIG野球まとめツール
    </v-app-bar-title>

    <v-spacer />

    <v-menu>
      <template v-slot:activator="{ props }">
        <v-btn v-bind="props" icon="mdi-account-circle" variant="text" />
      </template>

      <v-list>
        <v-list-item>
          <v-list-item-title>{{ user?.name }}</v-list-item-title>
        </v-list-item>

        <v-divider />

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
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

const emit = defineEmits<{
  'toggle-drawer': []
}>()

const router = useRouter()
const { user, logout } = useAuth()

const handleLogout = async () => {
  await logout()
  router.push('/login')
}
</script>
