<template>
  <v-container>
    <v-row>
      <v-col cols="12">
        <h1 class="text-h4">カードセット管理</h1>
      </v-col>
    </v-row>

    <v-row>
      <v-col cols="12">
        <v-card>
          <v-card-title class="d-flex align-center"> カードセット一覧 </v-card-title>
          <v-card-text>
            <v-alert
              v-if="errorMessage"
              type="error"
              variant="tonal"
              class="mb-3"
              closable
              @click:close="errorMessage = ''"
            >
              {{ errorMessage }}
            </v-alert>
            <v-data-table
              :headers="headers"
              :items="cardSets"
              :loading="loading"
              class="elevation-1"
              density="compact"
            >
              <template v-slot:[`item.actions`]="{ item }">
                <v-icon size="small" @click="showDetail(item)" title="詳細">mdi-eye</v-icon>
              </template>
            </v-data-table>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- 詳細パネル -->
    <v-row v-if="selectedCardSet">
      <v-col cols="12">
        <v-card>
          <v-card-title class="d-flex align-center">
            カードセット詳細
            <v-spacer></v-spacer>
            <v-icon @click="selectedCardSet = null">mdi-close</v-icon>
          </v-card-title>
          <v-card-text>
            <v-row>
              <v-col cols="12" sm="4"><strong>セット名:</strong> {{ selectedCardSet.name }}</v-col>
              <v-col cols="12" sm="4"><strong>年度:</strong> {{ selectedCardSet.year }}</v-col>
              <v-col cols="12" sm="4"><strong>種別:</strong> {{ selectedCardSet.set_type }}</v-col>
            </v-row>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'
import { useSnackbar } from '@/composables/useSnackbar'

interface CardSet {
  id: number
  year: number
  set_type: string
  name: string
}

const { showSnackbar } = useSnackbar()

const cardSets = ref<CardSet[]>([])
const loading = ref(false)
const errorMessage = ref('')
const selectedCardSet = ref<CardSet | null>(null)

const headers = [
  { title: 'ID', key: 'id', width: '80px' },
  { title: '年度', key: 'year' },
  { title: '種別', key: 'set_type' },
  { title: 'セット名', key: 'name' },
  { title: '操作', key: 'actions', sortable: false, width: '80px' },
]

onMounted(fetchCardSets)

async function fetchCardSets() {
  loading.value = true
  try {
    const response = await axios.get<CardSet[]>('/card_sets')
    cardSets.value = response.data
  } catch (error) {
    errorMessage.value = 'カードセットの取得に失敗しました'
    showSnackbar('カードセットの取得に失敗しました', 'error')
    console.error('Error fetching card sets:', error)
  } finally {
    loading.value = false
  }
}

async function showDetail(item: CardSet) {
  try {
    const response = await axios.get<CardSet>(`/card_sets/${item.id}`)
    selectedCardSet.value = response.data
  } catch (error) {
    errorMessage.value = 'カードセット詳細の取得に失敗しました'
    showSnackbar('カードセット詳細の取得に失敗しました', 'error')
    console.error('Error fetching card set detail:', error)
  }
}
</script>
