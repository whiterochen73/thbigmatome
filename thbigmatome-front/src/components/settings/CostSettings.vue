<template>
  <v-card>
    <v-card-title>
      {{ t('settings.cost.title') }}
      <v-spacer></v-spacer>
      <v-btn color="primary" @click="openDialog(null)">
        {{ t('settings.cost.add') }}
      </v-btn>
    </v-card-title>
    <v-data-table :headers="headers" :items="costs" class="elevation-1">
      <template v-slot:item.actions="{ item }">
        <v-icon size="small" class="mr-2" @click="openDialog(item)" icon="mdi-pencil"></v-icon>
        <v-icon size="small" @click="deleteItem(item)" icon="mdi-delete"></v-icon>
      </template>
    </v-data-table>

    <CostDialog :model-value="dialogOpen" :cost="selectedCost" @update:model-value="dialogOpen = $event" @save="saveCost" />
  </v-card>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import axios from '@/plugins/axios';
import CostDialog from '@/components/settings/CostDialog.vue';

const { t } = useI18n();

interface Cost {
  id: number;
  name: string;
  start_date: string | null;
  end_date: string | null;
}

const costs = ref<Cost[]>([]);
const dialogOpen = ref(false);
const selectedCost = ref<Cost | null>(null);

const headers = computed(() => [
  { title: t('settings.cost.headers.name'), key: 'name' },
  { title: t('settings.cost.headers.start_date'), key: 'start_date' },
  { title: t('settings.cost.headers.end_date'), key: 'end_date' },
  { title: t('settings.cost.headers.actions'), key: 'actions', sortable: false },
]);

const fetchCosts = async () => {
  const response = await axios.get<Cost[]>('/costs');
  costs.value = response.data;
};

const openDialog = (cost: Cost | null) => {
  selectedCost.value = cost ? { ...cost } : null;
  dialogOpen.value = true;
};

const saveCost = async (costData: { name: string; start_date: string | null; end_date: string | null }) => {
  if (selectedCost.value) {
    // Update existing cost
    await axios.patch(`/costs/${selectedCost.value.id}`, costData);
  } else {
    // Create new cost
    await axios.post('/costs', costData);
  }
  fetchCosts();
  dialogOpen.value = false;
};

const deleteItem = async (cost: Cost) => {
  if (confirm(t('settings.cost.confirmDelete'))) {
    await axios.delete(`/costs/${cost.id}`);
    fetchCosts();
  }
};

onMounted(() => {
  fetchCosts();
});
</script>