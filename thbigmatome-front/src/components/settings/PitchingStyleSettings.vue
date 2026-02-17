<template>
  <GenericMasterSettings
    :title="t('settings.pitchingStyle.title')"
    endpoint="/pitching-styles"
    i18n-key="settings.pitchingStyle"
    :dialog-component="PitchingStyleDialog"
    description-max-width="500px"
    :readonly="true"
  />
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import GenericMasterSettings from '@/components/settings/GenericMasterSettings.vue'
import PitchingStyleDialog from '@/components/settings/PitchingStyleDialog.vue'

const { t } = useI18n()
</script>
