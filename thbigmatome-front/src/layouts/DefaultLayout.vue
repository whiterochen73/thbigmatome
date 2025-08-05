<template>
  <v-app>
    <v-app-bar color="primary" dark>
      <v-app-bar-nav-icon @click.stop="drawer = !drawer" />
      <v-app-bar-title @click="goToMenu" style="cursor: pointer;">
        <v-icon start>mdi-baseball</v-icon>
        {{ t('layout.appTitle') }}
      </v-app-bar-title>

      <v-spacer />

      <v-menu>
        <template v-slot:activator="{ props }">
          <v-btn
            v-bind="props"
            icon="mdi-account-circle"
            variant="text"
          />
        </template>

        <v-list>
          <v-list-item>
            <v-list-item-title>
              {{ user?.name }}
            </v-list-item-title>
          </v-list-item>

          <v-divider />

          <v-list-item @click="handleLogout">
            <v-list-item-title>
              <v-icon start>mdi-logout</v-icon>
              {{ t('layout.logout') }}
            </v-list-item-title>
          </v-list-item>
        </v-list>
      </v-menu>
    </v-app-bar>

    <v-navigation-drawer
      v-model="drawer"
      :rail="rail"
      @click="expandDrawer"
    >
      <v-list nav density="compact">
        <v-list-item
          v-for="item in menuItems"
          :key="item.value"
          :prepend-icon="item.icon"
          :title="item.title"
          :value="item.value"
          :to="item.to"
          link
        />
      </v-list>
      <template v-slot:append>
        <v-list-item
          @click.stop="rail = !rail"
          :prepend-icon="rail ? 'mdi-chevron-right' : 'mdi-chevron-left'"
          :title="rail ? t('navigation.expand') : t('navigation.collapse')"
        >
        </v-list-item>
      </template>
    </v-navigation-drawer>
    <v-main>
      <router-view />
    </v-main>

    <v-snackbar
      :model-value="isSnackbarVisible"
      :color="snackbarColor"
      :timeout="snackbarTimeout"
      variant="tonal"
      location="top"
    >
      {{ snackbarMessage }}
    </v-snackbar>
  </v-app>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useSnackbar } from '@/composables/useSnackbar'
import { useI18n } from 'vue-i18n'
import { ref, computed } from 'vue';

const router = useRouter()
const { user, logout } = useAuth()
const { t } = useI18n()
const { isVisible: isSnackbarVisible, message: snackbarMessage, color: snackbarColor, timeout: snackbarTimeout } = useSnackbar()

const menuItems = computed(() => [
  { title: t('navigation.dashboard'), icon: 'mdi-view-dashboard', value: 'dashboard', to: '/menu' },
  { title: t('navigation.managers'), icon: 'mdi-account-supervisor', value: 'managers', to: '/managers' },
  { title: t('navigation.teams'), icon: 'mdi-account-group', value: 'teams', to: '/teams' },
  { title: t('navigation.players'), icon: 'mdi-account-multiple', value: 'players', to: '/players' },
  { title: t('navigation.costAssignment'), icon: 'mdi-currency-usd', value: 'costAssignment', to: '/cost_assignment' },
  { title: t('navigation.settings'), icon: 'mdi-cog', value: 'settings', to: '/settings' },
]);

const handleLogout = async () => {
  await logout()
  router.push('/login')
}

const drawer = ref(true)
const rail = ref(false)
const goToMenu = () => {
  router.push('/menu')
}

/**
 * 縮小表示されているナビゲーションドロワーを展開する
 */
const expandDrawer = () => {
  if (rail.value) rail.value = false;
}
</script>