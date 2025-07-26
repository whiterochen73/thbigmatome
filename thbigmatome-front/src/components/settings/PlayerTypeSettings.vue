<template>
  <GenericMasterSettings
    :title="t('settings.playerType.title')"
    endpoint="/player-types"
    i18n-key="settings.playerType"
    :dialog-component="PlayerTypeDialog"
    description-max-width="500px"
  />
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import GenericMasterSettings from '@/components/settings/GenericMasterSettings.vue'
import PlayerTypeDialog from '@/components/settings/PlayerTypeDialog.vue'

const { t } = useI18n()
</script>