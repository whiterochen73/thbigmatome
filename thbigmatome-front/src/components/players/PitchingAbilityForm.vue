<template>
  <div>

    <v-row dense>
      <v-col cols="12" sm="2">
        <v-text-field
          v-model.number="editableItem.starter_stamina"
          :label="t('playerDialog.form.starter_stamina')"
          type="number"
          :disabled="editableItem.is_relief_only"
          density="compact"
          @keydown="onStarterStaminaKeydown"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="2">
        <v-text-field
          v-model.number="editableItem.relief_stamina"
          :label="t('playerDialog.form.relief_stamina')"
          ref="reliefStaminaInput"
          type="number"
          density="compact"
          @keydown="onReliefStaminaKeydown"
        ></v-text-field>
      </v-col>
      <v-col cols="6" sm="2">
        <v-checkbox
          v-model="editableItem.is_relief_only"
          :label="t('playerDialog.form.is_relief_only')"
          density="compact"
        ></v-checkbox>
      </v-col>
      <v-col cols="12" sm="6">
        <v-select
          v-model="editableItem.pitching_skill_ids"
          :items="pitchingSkills"
          :label="t('playerDialog.form.pitching_skills')"
          item-title="name"
          item-value="id"
          multiple
          chips
          clearable
          density="compact"
        ></v-select>
      </v-col>
    </v-row>
    <v-row dense>
      <v-col cols="12" sm="3">
        <v-select
          v-model="editableItem.pitching_style_id"
          :items="pitchingStyles"
          :label="t('playerDialog.form.pitching_style')"
          item-title="name"
          item-value="id"
          clearable
          density="compact"
        ></v-select>
      </v-col>
      <v-col cols="12" sm="3">
        <v-select
          v-model="editableItem.pinch_pitching_style_id"
          :items="pitchingStyles"
          :label="t('playerDialog.form.pinch_pitching_style')"
          item-title="name"
          item-value="id"
          clearable
          density="compact"
        ></v-select>
      </v-col>
      <v-col cols="12" sm="4">
        <v-text-field
          v-model="editableItem.pitching_style_description"
          :label="t('playerDialog.form.pitching_style_description')"
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="2">
        <v-checkbox
          v-model="showPartnerCatchers"
          :label="t('playerDialog.form.hasPartnerCatchers')"
          density="compact"
        ></v-checkbox>
      </v-col>
    </v-row>
    <v-row dense v-show="showPartnerCatchers">
      <v-col cols="12" sm="6">
        <PlayerSelect
          v-model="editableItem.catcher_ids"
          :players="catchers"
          :label="t('playerDialog.form.catchers')"
        />
      </v-col>
      <v-col cols="12" sm="3">
        <v-select
          v-model="editableItem.catcher_pitching_style_id"
          :items="pitchingStyles"
          :label="t('playerDialog.form.catcher_pitching_style')"
          item-title="name"
          item-value="id"
          clearable
          density="compact"
        ></v-select>
      </v-col>
    </v-row>

  </div>
</template>

<script setup lang="ts">
import type { PlayerPayload } from '@/types/playerPayload';
import { onMounted, ref, useTemplateRef, watch } from 'vue';
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import type { PitchingStyle } from '@/types/pitchingStyle'
import type { PitchingSkill } from '@/types/pitchingSkill'
import { useI18n } from 'vue-i18n';
import PlayerSelect from '@/components/shared/PlayerSelect.vue';

const editableItem = defineModel<PlayerPayload>({
  type: Object,
  required: true,
});
const { t } = useI18n();
const { showSnackbar } = useSnackbar()

const pitchingStyles = ref<PitchingStyle[]>([])
const pitchingSkills = ref<PitchingSkill[]>([])
const catchers = ref<PlayerPayload[]>([])

const showPartnerCatchers = ref(false)

const fetchPitchingStyles = async () => {
  try {
    const response = await axios.get<PitchingStyle[]>('/pitching-styles')
    pitchingStyles.value = response.data
  } catch (error) {
    showSnackbar(t('playerDialog.notifications.fetchPitchingStylesFailed'), 'error')
  }
}

const fetchPitchingSkills = async () => {
  try {
    const response = await axios.get<PitchingSkill[]>('/pitching-skills')
    pitchingSkills.value = response.data
  } catch (error) {
    showSnackbar(t('playerDialog.notifications.fetchPitchingSkillsFailed'), 'error')
  }
}

const fetchCatchers = async () => {
  try {
    const response = await axios.get<PlayerPayload[]>('/players')
    catchers.value = response.data
  } catch (error) {
    showSnackbar(t('playerDialog.notifications.fetchCatchersFailed'), 'error')
  }
}

onMounted(() => {
  fetchPitchingStyles()
  fetchPitchingSkills()
  fetchCatchers()
})

watch(() => editableItem, (newItem) => {
  if (newItem) {
    showPartnerCatchers.value = !!newItem.value.catcher_ids.length;
  }
}, { immediate: true, deep: true })


const reliefStaminaInput = useTemplateRef('reliefStaminaInput');

const onStarterStaminaKeydown = (event: KeyboardEvent) => {
  if (event.key === '/') {
    event.preventDefault();
    reliefStaminaInput.value?.focus();
  }
};

const onReliefStaminaKeydown = (event: KeyboardEvent) => {
  if (event.key.toUpperCase() === 'R') {
    editableItem.value.is_relief_only = true
    editableItem.value.starter_stamina = null
    event.preventDefault();
  }
};
</script>
