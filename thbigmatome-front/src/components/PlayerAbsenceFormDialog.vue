<template>
  <v-dialog v-model="isOpen" max-width="600px">
    <v-card>
      <v-card-title>
        <span class="text-h5">{{ newAbsence.id ? t('playerAbsenceDialog.title.edit') : t('playerAbsenceDialog.title.add') }}</span>
      </v-card-title>
      <v-card-text>
        <v-form ref="form">
          <v-container>
            <v-row>
              <v-col cols="12">
                <TeamMemberSelect
                  v-model="newAbsence.team_membership_id"
                  :team-id="props.teamId"
                  :label="t('playerAbsenceDialog.form.playerName')"
                  :rules="[v => !!v || t('playerAbsenceDialog.form.selectPlayerName')]"
                  required
                ></TeamMemberSelect>
              </v-col>
              <v-col cols="12">
                <v-select
                  v-model="newAbsence.absence_type"
                  :items="absenceTypes"
                  :label="t('playerAbsenceDialog.form.absenceType')"
                  :rules="[v => !!v || t('playerAbsenceDialog.form.selectAbsenceType')]"
                  required
                ></v-select>
              </v-col>
              <v-col cols="12">
                <v-text-field
                  v-model="newAbsence.reason"
                  :label="t('playerAbsenceDialog.form.reason')"
                  :rules="[v => !!v || t('playerAbsenceDialog.form.enterReason')]"
                  required
                ></v-text-field>
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field
                  v-model="newAbsence.start_date"
                  :label="t('playerAbsenceDialog.form.startDate')"
                  type="date"
                  :rules="[v => !!v || t('playerAbsenceDialog.form.selectStartDate')]"
                  required
                ></v-text-field>
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field
                  v-model="newAbsence.duration"
                  :label="t('playerAbsenceDialog.form.duration')"
                  type="number"
                  :rules="[v => !!v || t('playerAbsenceDialog.form.enterDuration'), v => v > 0 || t('playerAbsenceDialog.form.durationMin')]"
                  required
                ></v-text-field>
              </v-col>
              <v-col cols="12">
                <v-select
                  v-model="newAbsence.duration_unit"
                  :items="durationUnits"
                  :label="t('playerAbsenceDialog.form.durationUnit')"
                  :rules="[v => !!v || t('playerAbsenceDialog.form.selectDurationUnit')]"
                  required
                ></v-select>
              </v-col>
            </v-row>
          </v-container>
        </v-form>
      </v-card-text>
      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn color="blue-darken-1" variant="text" @click="isOpen = false">
          {{ t('actions.cancel') }}
        </v-btn>
        <v-btn color="blue-darken-1" variant="text" @click="saveAbsence">
          {{ t('actions.save') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import axios from 'axios';
import { useI18n } from 'vue-i18n';
import type { PlayerAbsence } from '@/types/playerAbsence';
import TeamMemberSelect from '@/components/shared/TeamMemberSelect.vue';

const { t } = useI18n();

const isOpen = defineModel({
  type: Boolean,
  default: false
})

const props = defineProps<{
  modelValue: boolean; // Controls dialog visibility
  seasonId: number;
  teamId: number;
  initialStartDate: string; // ADDED
  initialAbsence?: PlayerAbsence | null; // ADDED for editing
}>();

const emit = defineEmits(['saved']);

const form = ref<HTMLFormElement | null>(null);
const newAbsence = ref<PlayerAbsence>({
  id: 0,
  team_membership_id: 0,
  season_id: props.seasonId,
  absence_type: 'injury',
  reason: '',
  start_date: props.initialStartDate,
  duration: 1,
  duration_unit: 'days',
  created_at: '',
  updated_at: '',
  player_name: ''
});

const absenceTypes = computed(() => [
  { title: t('enums.player_absence.absence_type.injury'), value: 'injury' },
  { title: t('enums.player_absence.absence_type.suspension'), value: 'suspension' },
  { title: t('enums.player_absence.absence_type.reconditioning'), value: 'reconditioning' },
]);

const durationUnits = computed(() => [
  { title: t('enums.player_absence.duration_unit.days'), value: 'days' },
  { title: t('enums.player_absence.duration_unit.games'), value: 'games' },
]);


const saveAbsence = async () => {
  const { valid } = await form.value!.validate();
  if (!valid) return;

  try {
    newAbsence.value.season_id = props.seasonId;
    let response;
    if (newAbsence.value.id) {
      // Update existing absence
      response = await axios.put(`/player_absences/${newAbsence.value.id}`, newAbsence.value);
      console.log('Player absence updated:', response.data);
    } else {
      // Create new absence
      response = await axios.post('/player_absences', newAbsence.value);
      console.log('Player absence saved:', response.data);
    }
    emit('saved');
    isOpen.value = false;
  } catch (error) {
    console.error('Failed to save player absence:', error);
    // TODO: Display error message to user
  }
};

watch(() => isOpen.value, (newValue) => {
  if (newValue) {
    if (props.initialAbsence) {
      // Editing existing absence
      newAbsence.value = { ...props.initialAbsence };
    } else {
      // Creating new absence
      newAbsence.value = {
        id: 0,
        team_membership_id: null,
        season_id: props.seasonId,
        absence_type: 'injury',
        reason: '',
        start_date: props.initialStartDate, // Use initialStartDate for new entries
        duration: 1,
        duration_unit: 'days',
        created_at: '',
        updated_at: '',
        player_name: ''
      };
    }
    form.value?.resetValidation();
  }
});
</script>
