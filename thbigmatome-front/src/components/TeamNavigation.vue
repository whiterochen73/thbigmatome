<template>
  <v-tabs
    :model-value="activeTab"
    color="primary"
    density="comfortable"
    class="team-navigation mb-2"
  >
    <v-tab
      v-for="tab in tabs"
      :key="tab.routeName"
      :value="tab.routeName"
      :to="tab.to"
      :prepend-icon="tab.icon"
    >
      {{ tab.label }}
    </v-tab>
  </v-tabs>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  teamId: number | string
}>()

const { t } = useI18n()
const route = useRoute()

const tabs = computed(() => [
  {
    routeName: 'TeamMembers',
    label: t('teamNavigation.teamMembers'),
    icon: 'mdi-account-group',
    to: { name: 'TeamMembers', params: { teamId: props.teamId } },
  },
  {
    routeName: 'SeasonRoster',
    label: t('teamNavigation.activeRoster'),
    icon: 'mdi-clipboard-list',
    to: { name: 'SeasonRoster', params: { teamId: props.teamId } },
  },
  {
    routeName: 'SeasonPortal',
    label: t('teamNavigation.seasonPortal'),
    icon: 'mdi-calendar',
    to: { name: 'SeasonPortal', params: { teamId: props.teamId } },
  },
])

const activeTab = computed(() => {
  return route.name as string
})
</script>
