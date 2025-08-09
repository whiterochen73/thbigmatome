<template>
  <v-card>
    <v-card-title>
      {{ t('settings.schedule.title') }}
      <v-spacer></v-spacer>
      <v-btn color="primary" @click="openDialog(null)">
        {{ t('settings.schedule.add') }}
      </v-btn>
    </v-card-title>
    <v-data-table :headers="headers" :items="schedules" class="elevation-1">
      <template v-slot:item.actions="{ item }">
        <v-icon size="small" class="mr-2" @click="openScheduleDetailDialog(item)" icon="mdi-calendar-edit"></v-icon>
        <v-icon size="small" class="mr-2" @click="openDialog(item)" icon="mdi-pencil"></v-icon>
        <v-icon size="small" @click="deleteItem(item)" icon="mdi-delete"></v-icon>
      </template>
    </v-data-table>

    <ScheduleDialog v-model="isDialogOpen" :schedule="selectedSchedule" @save="fetchSchedules"/>
    <ScheduleDetailEditor v-model="isDetailEditorOpen" :schedule="selectedSchedule" @save="fetchSchedules" />

  </v-card>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import axios from '@/plugins/axios';
import ScheduleDialog from './ScheduleDialog.vue';
import ScheduleDetailEditor from './ScheduleDetailEditor.vue';
import type { ScheduleList } from '@/types/scheduleList';

const { t } = useI18n();

const schedules = ref<ScheduleList[]>([]);
const isDialogOpen = ref(false);
const isDetailEditorOpen = ref(false);

const selectedSchedule = ref<ScheduleList | null>(null);

const headers = computed(() => [
  { title: t('settings.schedule.headers.name'), key: 'name' },
  { title: t('settings.schedule.headers.start_date'), key: 'start_date' },
  { title: t('settings.schedule.headers.end_date'), key: 'end_date' },
  { title: t('settings.schedule.headers.effective_date'), key: 'effective_date' },
  { title: t('settings.schedule.headers.actions'), key: 'actions', sortable: false },
]);

const fetchSchedules = async () => {
  const response = await axios.get<ScheduleList[]>('/schedules');
  schedules.value = response.data;
};

const openDialog = (schedule: ScheduleList | null) => {
  selectedSchedule.value = schedule ? { ...schedule } : null;
  isDialogOpen.value = true;
};

const openScheduleDetailDialog = (schedule: ScheduleList) => {
  selectedSchedule.value = { ...schedule };
  isDetailEditorOpen.value = true;
};

const deleteItem = async (schedule: ScheduleList) => {
  if (confirm(t('schedule.confirmDelete'))) {
    await axios.delete(`/schedules/${schedule.id}`);
    fetchSchedules();
  }
};

onMounted(() => {
  fetchSchedules();
});
</script>