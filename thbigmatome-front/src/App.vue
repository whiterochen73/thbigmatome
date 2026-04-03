<template>
  <v-app>
    <router-view />
  </v-app>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useTheme } from 'vuetify'

const theme = useTheme()

onMounted(() => {
  const saved = localStorage.getItem('theme')
  if (saved) {
    // 旧テーマ名(thbigLight/thbigDark)をVuetify標準名に移行
    const validTheme = saved === 'thbigDark' ? 'dark' : saved === 'thbigLight' ? 'light' : saved
    theme.change(validTheme)
    if (validTheme !== saved) localStorage.setItem('theme', validTheme)
  }
  // 認証チェックはauthGuardに一本化（App.vueでの非同期checkAuth削除）
  // 理由: App.vueのonMountedとlogin()の間でレースコンディションが発生し、
  // login()完了後にcheckAuth()の401レスポンスがuser.valueをnullにリセットしていた
})
</script>

<style>
@import url('https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@400;500;700&family=Shippori+Mincho:wght@400;700&display=swap');

/* 和色パレット */
:root {
  --ai: var(--color-visitor);
  --ai-light: #2a5298;
  --shu: #b33333;
  --moegi: #5a8a00;
  --kohaku: #c87a10;
  --fuji: #6b4c8a;
  --usuiro: #d4c5a9;
  --shiro: #fafaf5;
  --kake: #f5f0e8;
}

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

.font-mono,
code,
pre,
.v-data-table td.numeric {
  font-family: 'JetBrains Mono', monospace;
}
</style>
