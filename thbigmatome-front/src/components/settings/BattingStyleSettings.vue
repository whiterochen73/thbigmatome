<template>
  <GenericMasterSettings
    :title="t('settings.battingStyle.title')"
    endpoint="/batting-styles"
    i18n-key="settings.battingStyle"
    :dialog-component="BattingStyleDialog"
    description-max-width="500px"
    :readonly="true"
  />
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import GenericMasterSettings from '@/components/settings/GenericMasterSettings.vue'
import BattingStyleDialog from '@/components/settings/BattingStyleDialog.vue'

const { t } = useI18n()
</script>
