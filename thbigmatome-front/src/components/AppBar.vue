<template>
  <v-app-bar color="primary" elevation="2" :height="xs ? 56 : 64">
    <v-app-bar-nav-icon @click.stop="emit('toggle-drawer')" />

    <!-- ロゴは PC で残し、スマホ幅ではタイトルを優先して隠す（タイトルが無い画面では出す） -->
    <v-app-bar-title
      v-if="showLogo"
      class="app-bar-logo"
      :class="{ 'app-bar-logo--with-heading': heading }"
      @click="router.push('/')"
    >
      <img class="header-logo" src="/logo-thbig-dugout.svg" alt="THBIG Dugout" />
    </v-app-bar-title>

    <div
      v-if="heading"
      class="app-bar-heading"
      :class="{ 'app-bar-heading--no-back': !heading.back }"
      data-testid="app-bar-heading"
    >
      <v-btn
        v-if="heading.back"
        :to="heading.back.to"
        variant="text"
        size="small"
        class="app-bar-heading__back"
        data-testid="app-bar-back"
        :aria-label="t('appBar.backTo', { label: heading.back.label })"
        ><v-icon class="app-bar-heading__back-icon" aria-hidden="true">mdi-arrow-left</v-icon>
        <span class="app-bar-heading__back-text">{{ heading.back.label }}</span></v-btn
      >
      <h1 class="app-bar-heading__title" data-testid="app-bar-title">{{ heading.title }}</h1>
      <span v-if="heading.subtitle" class="app-bar-heading__separator" aria-hidden="true">・</span>
      <span
        v-if="heading.subtitle"
        class="app-bar-heading__subtitle"
        data-testid="app-bar-subtitle"
        >{{ heading.subtitle }}</span
      >
    </div>

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

        <v-list-item to="/settings" data-testid="menu-settings">
          <v-list-item-title>
            <v-icon start>mdi-cog-outline</v-icon>
            設定
          </v-list-item-title>
        </v-list-item>

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
import { computed, watchEffect } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useDisplay, useTheme } from 'vuetify'
import { useI18n } from 'vue-i18n'
import { useAuth } from '@/composables/useAuth'
import { appBarShownTitle, appBarTitle, type AppBarTitle } from '@/composables/useAppBarTitle'

const emit = defineEmits<{
  'toggle-drawer': []
}>()

const router = useRouter()
const route = useRoute()
const { xs } = useDisplay()
const { t } = useI18n()
const { user, logout } = useAuth()
const theme = useTheme()

// 画面が宣言したタイトルを優先し、無ければ route.meta.title を出す（全画面にタイトルが出る）
const heading = computed<AppBarTitle | null>(() => {
  if (appBarTitle.value) return appBarTitle.value
  const metaTitle = route.meta?.title
  return typeof metaTitle === 'string' && metaTitle ? { title: metaTitle } : null
})
const showLogo = computed(() => !xs.value || !heading.value)

// まだ移していない画面の PageHeader が、バーと同じ題を二重に出さないための目印
watchEffect(() => {
  appBarShownTitle.value = heading.value?.title ?? ''
})

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

<style scoped>
.app-bar-logo {
  cursor: pointer;
  min-width: 0;
}
.app-bar-logo--with-heading {
  flex: 0 0 auto;
  margin-inline-end: 8px;
}
.header-logo {
  display: block;
  height: 36px;
  max-width: min(240px, 52vw);
  width: auto;
}

/* タイトル（h1）。PC は「戻り先 タイトル ・ サブタイトル」を 1 行、スマホは 2 段 */
.app-bar-heading {
  display: flex;
  align-items: baseline;
  flex: 1 1 auto;
  gap: 10px;
  min-width: 0;
  overflow: hidden;
  white-space: nowrap;
  color: rgb(var(--v-theme-on-primary));
}
.app-bar-heading__back {
  align-self: center;
  flex: 0 1 auto;
  min-width: 0;
  overflow: hidden;
}
.app-bar-heading__back :deep(.v-btn__content) {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
}
.app-bar-heading__back-icon {
  margin-inline-end: 2px;
}
.app-bar-heading__back-text {
  text-decoration: underline;
  text-underline-offset: 3px;
  text-transform: none;
  letter-spacing: 0;
}
.app-bar-heading__separator {
  flex: none;
  align-self: center;
  margin-inline: -4px;
}
.app-bar-heading__title {
  margin: 0;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 1.125rem;
  font-weight: 700;
  line-height: 1.3;
  /* 明朝（global の h1 指定）は使わない。バーのタイトルはゴシック 700 */
  font-family: inherit;
}
.app-bar-heading__subtitle {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 0.8125rem;
  font-weight: 400;
}

@media (max-width: 599.98px) {
  .app-bar-heading {
    display: grid;
    grid-template-columns: auto minmax(0, 1fr);
    column-gap: 2px;
    align-items: center;
    row-gap: 0;
  }
  .app-bar-heading--no-back {
    grid-template-columns: minmax(0, 1fr);
  }
  .app-bar-heading__back {
    grid-row: 1 / 3;
    width: 32px;
    min-width: 32px;
    padding-inline: 0;
  }
  .app-bar-heading__back-icon {
    margin-inline-end: 0;
  }
  .app-bar-heading__back-text {
    display: none;
  }
  .app-bar-heading__separator {
    display: none;
  }
  .app-bar-heading__title {
    font-size: 1rem;
    line-height: 1.2;
  }
  .app-bar-heading__subtitle {
    font-size: 0.75rem;
    font-weight: 500;
    line-height: 1.2;
  }
}
</style>
