<template>
    <v-select
      v-model="costList"
      :items="costLists"
      item-title="name"
      item-value="id"
    ></v-select>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from '@/plugins/axios';
import type { CostList } from '@/types/costList'

const costList = defineModel<CostList | null>()
const costLists = ref<CostList[]>([]);

const fetchCostLists = async () => {
  const response = await axios.get<CostList[]>('/costs')
  costLists.value = response.data
}

onMounted(async () => {
  await fetchCostLists()

  if(!costList.value) {
    // 初期値が設定されていない場合、現在日時が含まれるコスト表を選択
    const now = new Date();
    const currentCost = costLists.value.find(cost => {
      const startDate = new Date(cost.start_date || '')
      const endDate = new Date(cost.end_date || '')
      return startDate <= now && (endDate >= now || !cost.end_date)
    })
    if (currentCost) {
      costList.value = currentCost
    } else {
      costList.value = costLists.value[0] // デフォルトで最初のコスト表を選択
    }
  }
})
</script>
