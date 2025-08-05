<template>
  <div>
    <v-row>
      <v-col cols="12" sm="2">
        <v-text-field
          v-model.number="editableItem.steal_start"
          :label="t('playerDialog.form.steal_start')"
          type="number"
          :rules="[rules.required]"
          required
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="2">
        <v-text-field
          v-model.number="editableItem.steal_end"
          :label="t('playerDialog.form.steal_end')"
          type="number"
          :rules="[rules.required]"
          required
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="2">
        <v-text-field
          v-model.number="editableItem.bunt"
          :label="t('playerDialog.form.bunt')"
          type="number"
          :rules="[rules.required]"
          required
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="2">
        <v-text-field
          v-model.number="editableItem.speed"
          :label="t('playerDialog.form.speed')"
          type="number"
          :rules="[rules.required]"
          required
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="2">
        <v-text-field
          v-model.number="editableItem.injury_rate"
          :label="t('playerDialog.form.injury_rate')"
          type="number"
          :rules="[rules.required]"
          required
          density="compact"
        ></v-text-field>
      </v-col>
    </v-row>
    <v-row dense>
      <v-col cols="12" sm="3">
        <v-select
          v-model="editableItem.batting_style_id"
          :items="battingStyles"
          :label="t('playerDialog.form.batting_style')"
          item-title="name"
          item-value="id"
          clearable
          density="compact"
        ></v-select>
      </v-col>
      <v-col cols="12" sm="5">
        <v-text-field
          v-model="editableItem.batting_style_description"
          :label="t('playerDialog.form.batting_style_description')"
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="4">
        <v-select
          v-model="editableItem.batting_skill_ids"
          :items="battingSkills"
          :label="t('playerDialog.form.batting_skills')"
          item-title="name"
          item-value="id"
          multiple
          chips
          clearable
          density="compact"
        ></v-select>
      </v-col>
    </v-row>
    <v-row dense v-if="isBiorhythmEnabled">
      <v-col cols="12" sm="5">
        <v-select
          v-model="editableItem.biorhythm_ids"
          :items="biorhythms"
          :label="t('playerDialog.form.biorhythms')"
          item-title="name"
          item-value="id"
          multiple
          density="compact"
          chips
          clearable
        ></v-select>
      </v-col>
    </v-row>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import type { BattingStyle } from '@/types/battingStyle'
import type { BattingSkill } from '@/types/battingSkill'
import type { Biorhythm } from '@/types/biorhythm'
import { useI18n } from 'vue-i18n';
import type { PlayerPayload } from '@/types/player';

const editableItem = defineModel<PlayerPayload>({
  type: Object,
  required: true,
});
const { t } = useI18n();
const { showSnackbar } = useSnackbar()

const battingStyles = ref<BattingStyle[]>([])
const battingSkills = ref<BattingSkill[]>([])
const biorhythms = ref<Biorhythm[]>([])

const isBiorhythmEnabled = computed(() => {
  return editableItem.value.batting_skill_ids.includes(3) ||
         editableItem.value.pitching_skill_ids.includes(10);
});

const rules = {
  required: (value: string | number) => (value !== null && value !== '') || t('validation.required')
};

const fetchBattingStyles = async () => {
  try {
    const response = await axios.get<BattingStyle[]>('/batting-styles')
    battingStyles.value = response.data
  } catch (error) {
    showSnackbar(t('playerDialog.notifications.fetchBattingStylesFailed'), 'error')
  }
}

const fetchBattingSkills = async () => {
  try {
    const response = await axios.get<BattingSkill[]>('/batting-skills')
    battingSkills.value = response.data
  } catch (error) {
    showSnackbar(t('playerDialog.notifications.fetchBattingSkillsFailed'), 'error')
  }
}

const fetchBiorhythms = async () => {
  try {
    const response = await axios.get<Biorhythm[]>('/biorhythms')
    biorhythms.value = response.data
  } catch (error) {
    showSnackbar(t('playerDialog.notifications.fetchBiorhythmsFailed'), 'error')
  }
}

onMounted(() => {
  fetchBattingStyles()
  fetchBattingSkills()
  fetchBiorhythms()
})

</script>
