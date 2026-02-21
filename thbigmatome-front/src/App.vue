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
@import url('https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@400;500;700&family=Shippori+Mincho:wght@400;700&display=swap');

/* グローバルスタイル */
html {
  overflow-y: auto;
}

body {
  margin: 0;
  font-family: 'Noto Sans JP', sans-serif;
}

.v-application {
  font-family: 'Noto Sans JP', sans-serif !important;
}

h1,
h2,
h3,
.text-h4,
.text-h5,
.text-h6 {
  font-family: 'Shippori Mincho', serif;
}
</style>
