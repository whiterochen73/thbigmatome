<template>
  <v-app>
    <router-view />
  </v-app>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useAuth } from '@/composables/useAuth'

// アプリケーション起動時に認証状態をチェック
const { checkAuth } = useAuth()

onMounted(async () => {
  try {
    await checkAuth()
  } catch (error) {
    // 認証チェックに失敗した場合のエラーハンドリング
    // 例: エラーページにリダイレクト、トースト通知の表示など
    console.error('Authentication check failed:', error)
  }
})
</script>

<style>
/* グローバルスタイル */
html {
  overflow-y: auto;
}

body {
  margin: 0;
  font-family: 'Roboto', sans-serif;
}

/* Vuetifyのデフォルトスタイルを使用 */
</style>
