<template>
  <MasterPanel
    :title="t('settings.cost.title')"
    icon="mdi-cash-multiple"
    :count="costs.length"
    default-open
  >
    <template #actions>
      <MasterAddButton :label="t('settings.cost.add')" @click="openDialog(null)" />
    </template>
    <!-- eslint-disable vue/valid-v-slot -->
    <AsyncState
      :loading="loading"
      :error="fetchFailed"
      :error-message="t('settings.cost.notifications.fetchFailed')"
      :empty="costs.length === 0"
      :empty-message="t('settings.cost.notifications.noData')"
      @retry="fetchCosts"
    >
      <v-data-table :headers="headers" :items="costs" class="ui-table--rows" mobile-breakpoint="sm">
        <template v-slot:item.actions="{ item }">
          <!-- 操作が 3 つあるので、スマホ（<600px）では操作メニューにまとめる -->
          <div class="row-actions row-actions--full">
            <RowIconButton
              icon="mdi-pencil"
              :label="t('settings.rowActions.edit', { name: item.name })"
              @click="openDialog(item)"
            />
            <RowIconButton
              icon="mdi-content-copy"
              :label="t('settings.rowActions.duplicate', { name: item.name })"
              @click="confirmDuplicate(item)"
            />
            <RowIconButton
              icon="mdi-delete-outline"
              danger
              :label="t('settings.rowActions.delete', { name: item.name })"
              @click="deleteItem(item)"
            />
          </div>
          <RowMenu
            :label="t('settings.rowActions.menu', { name: item.name })"
            :items="[
              {
                icon: 'mdi-pencil',
                label: t('settings.rowActions.editShort'),
                onClick: () => openDialog(item),
              },
              {
                icon: 'mdi-content-copy',
                label: t('settings.rowActions.duplicateShort'),
                onClick: () => confirmDuplicate(item),
              },
              {
                icon: 'mdi-delete-outline',
                label: t('settings.rowActions.deleteShort'),
                danger: true,
                onClick: () => deleteItem(item),
              },
            ]"
          />
        </template>
      </v-data-table>
    </AsyncState>

    <CostDialog
      :model-value="dialogOpen"
      :cost="selectedCost"
      @update:model-value="dialogOpen = $event"
      @save="saveCost"
    />
  </MasterPanel>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import axios from '@/plugins/axios'
import CostDialog from '@/components/settings/CostDialog.vue'
import MasterPanel from '@/components/settings/MasterPanel.vue'
import MasterAddButton from '@/components/settings/MasterAddButton.vue'
import AsyncState from '@/components/shared/AsyncState.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'
import RowMenu from '@/components/shared/RowMenu.vue'
import { tableCell } from '@/components/shared/tableCells'
import type { CostList } from '@/types/costList'

const { t } = useI18n()

const costs = ref<CostList[]>([])
const loading = ref(true)
const fetchFailed = ref(false)
const dialogOpen = ref(false)
const selectedCost = ref<CostList | null>(null)

const headers = computed(() => [
  { title: t('settings.cost.headers.name'), key: 'name', cellProps: tableCell.title },
  {
    title: t('settings.cost.headers.start_date'),
    key: 'start_date',
    cellProps: tableCell.sub1Labeled,
  },
  { title: t('settings.cost.headers.end_date'), key: 'end_date', cellProps: tableCell.sub2Labeled },
  {
    title: t('settings.cost.headers.actions'),
    key: 'actions',
    sortable: false,
    align: 'end' as const,
    cellProps: tableCell.act,
  },
])

const fetchCosts = async () => {
  loading.value = true
  fetchFailed.value = false
  try {
    const response = await axios.get<CostList[]>('/costs')
    costs.value = response.data
  } catch {
    fetchFailed.value = true
  } finally {
    loading.value = false
  }
}

const openDialog = (cost: CostList | null) => {
  selectedCost.value = cost ? { ...cost } : null
  dialogOpen.value = true
}

const saveCost = async (costData: {
  name: string
  start_date: string | null
  end_date: string | null
}) => {
  if (selectedCost.value) {
    // Update existing cost
    await axios.patch(`/costs/${selectedCost.value.id}`, costData)
  } else {
    // Create new cost
    await axios.post('/costs', costData)
  }
  fetchCosts()
  dialogOpen.value = false
}

const deleteItem = async (cost: CostList) => {
  if (confirm(t('settings.cost.confirmDelete'))) {
    await axios.delete(`/costs/${cost.id}`)
    fetchCosts()
  }
}

const confirmDuplicate = (cost: CostList) => {
  if (confirm(`${cost.name} を複製しますか？`)) {
    duplicateCost(cost)
  }
}

const duplicateCost = async (cost: CostList) => {
  try {
    await axios.post(`/costs/${cost.id}/duplicate`)
    fetchCosts()
  } catch (error) {
    console.error('Failed to duplicate cost:', error)
  }
}

onMounted(() => {
  fetchCosts()
})
</script>
