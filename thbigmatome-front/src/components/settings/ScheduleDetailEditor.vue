<template>
  <v-dialog v-model="isOpen" max-width="600px">
    <v-card>
      <v-card-title>{{ t('settings.schedule.detail.title') }}</v-card-title>
      <v-card-text>
        <v-row>
          <v-col cols="4">
            {{ calendarDate ? calendarDate.toLocaleDateString() : t('settings.schedule.detail.selectDate') }}
            <v-radio-group v-model="selectedDateType">
              <v-radio v-for="(type, i) in dateTypes" :key="i" :label="type.label" :value="type.value">
                <template #label>
                  <v-chip :color="type.color" text-color="white" class="mr-2">
                    {{ type.label }}
                  </v-chip>
                </template>
              </v-radio>
            </v-radio-group>
          </v-col>
          <v-col cols="8">
            <v-date-picker
              v-model="calendarDate"
              :title="t('settings.schedule.detail.datePickerTitle')"
              :min="props.schedule?.start_date"
              :max="props.schedule?.end_date"
              :first-day-of-week="1"
              show-adjacent-months
            >
              <template #day="{ item }">
                <v-btn
                  :color="dateTypes.find(type => type.value === scheduleDetails.find(detail =>
                      detail.date === dateToString(item.date)
                    )?.date_type)?.color || 'transparent'"
                  block
                  flat
                  :disabled="item.isDisabled"
                  :title="dateTypes.find(type => type.value === scheduleDetails.find(detail =>
                      detail.date === dateToString(item.date)
                    )?.date_type)?.label || ''"
                  @click="calendarDate = item.date;console.log('Selected date:', item)"
                >
                  {{ item.date.getDate() }}
                </v-btn>
              </template>
            </v-date-picker>
          </v-col>
        </v-row>
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
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDate } from 'vuetify';
import axios from '@/plugins/axios';
import type { ScheduleList } from '@/types/scheduleList';
import type { ScheduleDetail } from '@/types/scheduleDetail';

const { t } = useI18n();
const date = useDate();

const isOpen = defineModel<boolean>();
const props = defineProps<{
  schedule: ScheduleList | null;
}>();

const emit = defineEmits<{
  (e: 'save'): void;
}>();

const scheduleDetails = ref<ScheduleDetail[]>([]);
const selectedDateType = ref<string>('game_day');
const calendarDate = ref<Date>(new Date());

const dateTypes = computed(() => [
  { label: t('settings.schedule.dateTypes.game_day'), value: 'game_day', color: 'blue' },
  { label: t('settings.schedule.dateTypes.interleague_game_day'), value: 'interleague_game_day', color: 'deep-purple' },
  { label: t('settings.schedule.dateTypes.playoff_day'), value: 'playoff_day', color: 'pink' },
  { label: t('settings.schedule.dateTypes.travel_day'), value: 'travel_day', color: 'grey' },
  { label: t('settings.schedule.dateTypes.reserve_day'), value: 'reserve_day', color: 'blue-grey' },
  { label: t('settings.schedule.dateTypes.interleague_reserve_day'), value: 'interleague_reserve_day', color: 'brown' },
  { label: t('settings.schedule.dateTypes.no_game_day'), value: 'no_game_day', color: 'red' },
]);

const fetchScheduleDetails = async () => {
  if (!props.schedule) return;
  const response = await axios.get<ScheduleDetail[]>(`/schedules/${props.schedule.id}/schedule_details`);
  scheduleDetails.value = response.data;
};

watch(() => props.schedule, async (newVal) => {
  if (newVal) {
    console.log('Fetching schedule details for:', newVal);
    calendarDate.value = new Date(newVal.start_date!);
    await fetchScheduleDetails();
  }
}, { immediate: true });

watch(isOpen, async (newVal) => {
  if (newVal) {
    await fetchScheduleDetails();
  }
});

watch(calendarDate, (newDate) => {
  console.log('Selected date:', newDate)
});

watch(selectedDateType, () => {
  // 日付タイプが変更されたら、選択されている日付のタイプを更新する
  if (!calendarDate.value || !props.schedule) return;
  const selectedDateStr = dateToString(calendarDate.value);
  const existingDetail = scheduleDetails.value.find(detail => detail.date === selectedDateStr);
  if (existingDetail) {
    existingDetail.date_type = selectedDateType.value;
  } else {
    scheduleDetails.value.push({
      date: selectedDateStr,
      date_type: selectedDateType.value,
      schedule_id: props.schedule!.id!,
    });
  }
});

const dateToString = (date: Date) => {
  return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
};


const closeDialog = () => {
  isOpen.value = false;
};

const save = async () => {
  if (!props.schedule) return;
  const payload = { schedule_details: scheduleDetails.value };
  await axios.post(`/schedules/${props.schedule.id}/schedule_details/upsert_all`, payload);
  emit('save');
  closeDialog();
};

</script>
