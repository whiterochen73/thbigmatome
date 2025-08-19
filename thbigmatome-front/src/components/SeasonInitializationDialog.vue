<template>
  <v-dialog :model-value="isVisible" persistent max-width="600px" @update:model-value="closeDialog">
    <v-card>
      <v-card-title>
        <span class="text-h5">{{ t('topMenu.seasonInitialization.title') }}</span>
      </v-card-title>
      <v-card-text>
        <v-container>
          <v-row>
            <v-col cols="12">
              <v-text-field
                v-model="seasonName"
                :label="t('topMenu.seasonInitialization.seasonNameLabel')"
                required
              ></v-text-field>
            </v-col>
            <v-col cols="12">
              <v-select
                v-model="selectedSchedule"
                :items="schedules"
                item-title="name"
                item-value="id"
                :label="t('topMenu.seasonInitialization.selectScheduleLabel')"
                required
              ></v-select>
            </v-col>
          </v-row>
        </v-container>
      </v-card-text>
      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn color="blue-darken-1" text @click="closeDialog">
          {{ t('common.close') }}
        </v-btn>
        <v-btn color="blue-darken-1" text @click="initializeSeasonAndCloseDialog">
          {{ t('topMenu.seasonInitialization.initializeButton') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import axios from 'axios';
import type { ScheduleList } from '@/types/scheduleList';
import type { Team } from '@/types/team';

const props = defineProps<{
  isVisible: boolean;
  schedules: ScheduleList[];
  selectedTeam: Team | null;
}>();

const emit = defineEmits(['update:isVisible', 'save']);

const { t } = useI18n();

const seasonName = ref('');
const selectedSchedule = ref<number | null>(null);

const closeDialog = () => {
  emit('update:isVisible', false);
};

const initializeSeason = async () => {
  if (!props.selectedTeam || !selectedSchedule.value || !seasonName.value) {
    console.error('Team, schedule, and season name are required.');
    return;
  }

  try {
    const response = await axios.post('/seasons', {
      team_id: props.selectedTeam.id,
      schedule_id: selectedSchedule.value,
      name: seasonName.value,
    });
    console.log('Season initialized:', response.data);
    seasonName.value = '';
    selectedSchedule.value = null;
    emit('save');
  } catch (error) {
    console.error('Failed to initialize season:', error);
  }
};

const initializeSeasonAndCloseDialog = async () => {
  await initializeSeason();
  closeDialog();
};

watch(() => props.isVisible, (newValue) => {
  if (!newValue) {
    seasonName.value = '';
    selectedSchedule.value = null;
  }
});
</script>
