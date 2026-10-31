<template>
  <v-app-bar color="primary" elevation="2" :height="64">
    <v-app-bar-nav-icon @click.stop="emit('toggle-drawer')" />

    <v-app-bar-title
      class="app-bar-title"
      :class="{ 'app-bar-title--with-breadcrumbs': appBarBreadcrumbs }"
      @click="router.push('/')"
    >
      <img class="header-logo" src="/logo-thbig-dugout.svg" alt="THBIG Dugout" />
    </v-app-bar-title>

    <nav
      v-if="appBarBreadcrumbs"
      class="app-bar-breadcrumbs"
      data-testid="app-bar-breadcrumbs"
      :aria-label="t('gameDay.breadcrumbs.label')"
    >
      <v-btn
        :to="appBarBreadcrumbs.seasonPortalRoute"
        variant="text"
        size="small"
        class="app-bar-breadcrumbs__link"
        :aria-label="t('seasonPortal.title')"
        ><v-icon class="app-bar-breadcrumbs__back" aria-hidden="true">mdi-arrow-left</v-icon>
        <span class="app-bar-breadcrumbs__link-text">{{ t('seasonPortal.title') }}</span></v-btn
      >
      <v-icon size="x-small" class="app-bar-breadcrumbs__separator" aria-hidden="true"
        >mdi-chevron-right</v-icon
      >
      <span class="app-bar-breadcrumbs__team">{{ appBarBreadcrumbs.teamName }}</span>
      <v-icon
        v-if="appBarBreadcrumbs.gameNumber !== null"
        size="x-small"
        class="app-bar-breadcrumbs__separator app-bar-breadcrumbs__game"
        aria-hidden="true"
        >mdi-chevron-right</v-icon
      >
      <span v-if="appBarBreadcrumbs.gameNumber !== null" class="app-bar-breadcrumbs__game"
        >Game {{ appBarBreadcrumbs.gameNumber }}</span
      >
      <span class="app-bar-breadcrumbs__date">{{ appBarBreadcrumbs.date }}</span>
    </nav>

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
import { useI18n } from 'vue-i18n'
import { useAuth } from '@/composables/useAuth'
import { appBarBreadcrumbs } from '@/composables/useAppBarBreadcrumbs'

const emit = defineEmits<{
  'toggle-drawer': []
}>()

const router = useRouter()
const { t } = useI18n()
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

<style scoped>
.app-bar-title {
  cursor: pointer;
  min-width: 0;
}
.app-bar-title--with-breadcrumbs {
  flex: 0 1 auto;
}
.app-bar-breadcrumbs {
  display: flex;
  align-items: center;
  flex: 1 1 auto;
  min-width: 0;
  overflow: hidden;
  white-space: nowrap;
  color: rgb(var(--v-theme-on-primary));
  gap: 4px;
}
.app-bar-breadcrumbs__link {
  flex: 0 1 auto;
  min-width: 0;
  overflow: hidden;
  text-decoration: underline;
  text-underline-offset: 2px;
}
.app-bar-breadcrumbs__link :deep(.v-btn__content) {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
}
.app-bar-breadcrumbs__back {
  display: none;
}
.app-bar-breadcrumbs__team {
  overflow: hidden;
  min-width: 0;
  text-overflow: ellipsis;
  font-weight: 700;
}
.app-bar-breadcrumbs__separator,
.app-bar-breadcrumbs__date,
.app-bar-breadcrumbs__game {
  flex-shrink: 0;
}
@media (max-width: 600px) {
  .app-bar-title--with-breadcrumbs {
    flex: 0 0 90px;
    width: 90px;
    margin-inline-start: 4px;
  }
  .app-bar-title--with-breadcrumbs .header-logo {
    width: 90px;
    max-width: none;
    height: auto;
  }
  .app-bar-breadcrumbs__link {
    flex: 0 0 32px;
    width: 32px;
    min-width: 32px;
    padding-inline: 0;
  }
  .app-bar-breadcrumbs__back {
    display: inline-flex;
  }
  .app-bar-breadcrumbs__link-text {
    display: none;
  }
  .app-bar-breadcrumbs__team,
  .app-bar-breadcrumbs__game,
  .app-bar-breadcrumbs__separator {
    display: none;
  }
  .app-bar-breadcrumbs__date {
    overflow: hidden;
    text-overflow: ellipsis;
    font-size: 0.75rem;
  }
}

.header-logo {
  display: block;
  height: 36px;
  max-width: min(240px, 52vw);
  width: auto;
}
</style>
