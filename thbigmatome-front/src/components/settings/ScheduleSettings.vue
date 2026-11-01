<template>
  <MasterPanel
    :title="t('settings.schedule.title')"
    icon="mdi-calendar-month"
    :count="schedules.length"
    default-open
  >
    <template #actions>
      <MasterAddButton :label="t('settings.schedule.add')" @click="openDialog(null)" />
    </template>
    <!-- eslint-disable vue/valid-v-slot -->
    <v-data-table :headers="headers" :items="schedules" mobile-breakpoint="sm">
      <template v-slot:item.actions="{ item }">
        <RowIconButton
          icon="mdi-calendar-edit"
          :label="t('settings.rowActions.editDetail', { name: item.name })"
          @click="openScheduleDetailDialog(item)"
        />
        <RowIconButton
          icon="mdi-pencil"
          :label="t('settings.rowActions.edit', { name: item.name })"
          @click="openDialog(item)"
        />
        <RowIconButton
          icon="mdi-delete-outline"
          danger
          :label="t('settings.rowActions.delete', { name: item.name })"
          @click="deleteItem(item)"
        />
      </template>
    </v-data-table>

    <ScheduleDialog v-model="isDialogOpen" :schedule="selectedSchedule" @save="fetchSchedules" />
    <ScheduleDetailEditor
      v-model="isDetailEditorOpen"
      :schedule="selectedSchedule"
      @save="fetchSchedules"
    />
  </MasterPanel>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import axios from '@/plugins/axios'
import ScheduleDialog from './ScheduleDialog.vue'
import ScheduleDetailEditor from './ScheduleDetailEditor.vue'
import MasterPanel from '@/components/settings/MasterPanel.vue'
import MasterAddButton from '@/components/settings/MasterAddButton.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'
import type { ScheduleList } from '@/types/scheduleList'

const { t } = useI18n()

const schedules = ref<ScheduleList[]>([])
const isDialogOpen = ref(false)
const isDetailEditorOpen = ref(false)

const selectedSchedule = ref<ScheduleList | null>(null)

const headers = computed(() => [
  { title: t('settings.schedule.headers.name'), key: 'name' },
  { title: t('settings.schedule.headers.start_date'), key: 'start_date' },
  { title: t('settings.schedule.headers.end_date'), key: 'end_date' },
  { title: t('settings.schedule.headers.effective_date'), key: 'effective_date' },
  {
    title: t('settings.schedule.headers.actions'),
    key: 'actions',
    sortable: false,
    align: 'end' as const,
  },
])

const fetchSchedules = async () => {
  const response = await axios.get<ScheduleList[]>('/schedules')
  schedules.value = response.data
}

const openDialog = (schedule: ScheduleList | null) => {
  selectedSchedule.value = schedule ? { ...schedule } : null
  isDialogOpen.value = true
}

const openScheduleDetailDialog = (schedule: ScheduleList) => {
  selectedSchedule.value = { ...schedule }
  isDetailEditorOpen.value = true
}

const deleteItem = async (schedule: ScheduleList) => {
  if (confirm(t('schedule.confirmDelete'))) {
    await axios.delete(`/schedules/${schedule.id}`)
    fetchSchedules()
  }
}

onMounted(() => {
  fetchSchedules()
})
</script>
