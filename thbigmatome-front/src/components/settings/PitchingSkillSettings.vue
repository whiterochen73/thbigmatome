<template>
  <GenericMasterSettings
    :title="t('settings.pitchingSkill.title')"
    icon="mdi-star-four-points"
    endpoint="/pitching-skills"
    i18n-key="settings.pitchingSkill"
    :dialog-component="PitchingSkillDialog"
    description-max-width="400px"
    :readonly="true"
  >
    <!-- eslint-disable-next-line vue/valid-v-slot -->
    <template #item.name="{ item }">
      <v-chip :color="getNameBackgroundColor(item.skill_type)" variant="flat" size="small" label>
        {{ item.name }}
      </v-chip>
    </template>
  </GenericMasterSettings>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import GenericMasterSettings from '@/components/settings/GenericMasterSettings.vue'
import PitchingSkillDialog from '@/components/settings/PitchingSkillDialog.vue'
import type { SkillType } from '@/types/skill'

const { t } = useI18n()

const getNameBackgroundColor = (skillType: SkillType) => {
  if (skillType === 'positive') return 'state-info'
  if (skillType === 'negative') return 'state-todo'
  return 'state-neutral'
}
</script>
