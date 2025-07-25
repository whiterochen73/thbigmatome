<template>
  <GenericMasterSettings
    :title="t('settings.biorhythm.title')"
    endpoint="/biorhythms"
    i18n-key="settings.biorhythm"
    :dialog-component="BiorhythmDialog"
    :has-description-column="false"
    :additional-headers="additionalHeaders"
  >
    <template #item.start_date="{ item }">
      {{ formatDate(item.start_date) }}
    </template>
    <template #item.end_date="{ item }">
      {{ formatDate(item.end_date) }}
    </template>
  </GenericMasterSettings>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import GenericMasterSettings from '@/components/settings/GenericMasterSettings.vue'
import BiorhythmDialog from '@/components/settings/BiorhythmDialog.vue'

const { t } = useI18n()

const additionalHeaders = computed(() => [
  { title: t('settings.biorhythm.headers.start_date'), key: 'start_date', sortable: true },
  { title: t('settings.biorhythm.headers.end_date'), key: 'end_date', sortable: true },
])

const formatDate = (dateString: string) => dateString ? dateString.substring(5).replace('-', '/') : ''
</script>