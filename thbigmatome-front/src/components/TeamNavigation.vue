<template>
  <v-card variant="outlined" class="mb-2">
    <v-tabs :model-value="activeTab" color="primary" density="comfortable" class="team-navigation">
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
  </v-card>
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
    to: { name: 'SeasonPortal', params: { teamId: props.teamId }, query: { tab: 'roster' } },
  },
  {
    routeName: 'SeasonPortal',
    label: t('teamNavigation.seasonPortal'),
    icon: 'mdi-calendar',
    to: { name: 'SeasonPortal', params: { teamId: props.teamId } },
  },
  {
    routeName: 'PlayerAbsenceHistory',
    label: t('teamNavigation.playerAbsenceHistory'),
    icon: 'mdi-account-off',
    to: { name: 'SeasonPortal', params: { teamId: props.teamId }, query: { tab: 'absences' } },
  },
])

const activeTab = computed(() => {
  if (route.name === 'SeasonPortal') {
    const tab = route.query.tab
    if (tab === 'roster') return 'SeasonRoster'
    if (tab === 'absences') return 'PlayerAbsenceHistory'
  }
  return route.name as string
})
</script>
