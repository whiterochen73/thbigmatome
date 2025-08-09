<template>
  <v-dialog v-model="isOpen" max-width="500px">
    <v-card>
      <v-card-title>{{ title }}</v-card-title>
      <v-card-text>
        <v-text-field
          v-model="editableSchedule.name"
          :label="t('settings.schedule.dialog.form.name')"
          :rules="[rules.required]"
        >
        </v-text-field>
        <v-text-field
          v-model="editableSchedule.start_date"
          :label="t('settings.schedule.dialog.form.start_date')"
          type="date"
          :rules="[rules.required]"
        >
        </v-text-field>
        <v-text-field
          v-model="editableSchedule.end_date"
          :label="t('settings.schedule.dialog.form.end_date')"
          type="date"
          :rules="[rules.required]"
        >
        </v-text-field>
        <v-text-field
          v-model="editableSchedule.effective_date"
          :label="t('settings.schedule.dialog.form.effective_date')"
          type="date"
        >
        </v-text-field>
      </v-card-text>
      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn color="blue-darken-1" variant="text" @click="closeDialog">{{ t('actions.cancel') }}</v-btn>
        <v-btn color="blue-darken-1" variant="text" @click="save">{{ t('actions.save') }}</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref, watch, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import axios from '@/plugins/axios';
import type { ScheduleList } from '@/types/scheduleList';

type ScheduleListPayload = Omit<ScheduleList, 'id'>

const { t } = useI18n();
const isOpen = defineModel<boolean>()
const props = defineProps<{
  schedule: ScheduleList | null;
}>();

const emit = defineEmits<{
  (e: 'save'): void;
}>();

const defaultSchedule: ScheduleListPayload = {
  name: '',
  start_date: null,
  end_date: null,
  effective_date: null,
};

const editableSchedule = ref<ScheduleListPayload>({ ...defaultSchedule });

watch(() => props.schedule, (newVal) => {
  if (newVal) {
    editableSchedule.value = { ...newVal };
  } else {
    editableSchedule.value = { ...defaultSchedule };
  }
});

const title = computed(() => {
  return props.schedule ? t('settings.schedule.dialog.title.edit') : t('settings.schedule.dialog.title.add');
});
const rules = {
  required: (value: string) => !!value || t('validation.required'),
}

const closeDialog = () => {
  isOpen.value = false;
};

const save = async () => {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const { id, ...scheduleData } = editableSchedule.value as ScheduleList;
  const payload = { schedule: scheduleData };

  if (props.schedule) {
    // Update existing schedule
    await axios.patch(`/schedules/${props.schedule.id}`, payload);
  } else {
    // Create new schedule
    await axios.post('/schedules', payload);
  }
  emit('save');
  closeDialog();
};
</script>