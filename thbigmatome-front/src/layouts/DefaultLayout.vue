<template>
  <v-app>
    <AppBar @toggle-drawer="drawer = !drawer" />

    <NavigationDrawer v-model="drawer" :rail="rail" @update:rail="rail = $event" />

    <v-main>
      <v-container fluid style="max-width: 1440px; margin: 0 auto; padding: 0">
        <router-view />
      </v-container>
    </v-main>

    <AppFooter />

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
import { ref } from 'vue'
import { useSnackbar } from '@/composables/useSnackbar'
import AppBar from '@/components/AppBar.vue'
import NavigationDrawer from '@/components/NavigationDrawer.vue'
import AppFooter from '@/components/AppFooter.vue'

const {
  isVisible: isSnackbarVisible,
  message: snackbarMessage,
  color: snackbarColor,
  timeout: snackbarTimeout,
} = useSnackbar()

const drawer = ref(true)
const rail = ref(false)
</script>
