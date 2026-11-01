<template>
  <PageLayout>
    <AsyncState
      framed
      :loading="loading"
      :error="fetchFailed"
      error-message="カードセットの取得に失敗しました"
      :empty="cardSets.length === 0"
      empty-icon="mdi-cards-outline"
      empty-message="カードセットが登録されていません"
      @retry="fetchCardSets"
    >
      <v-card>
        <v-data-table
          :headers="headers"
          :items="cardSets"
          class="ui-table ui-table--rows"
          density="compact"
          mobile-breakpoint="sm"
        >
          <template v-slot:[`item.actions`]="{ item }">
            <div class="row-actions">
              <RowIconButton
                icon="mdi-eye-outline"
                :label="`${item.name}の詳細`"
                @click="showDetail(item)"
              />
            </div>
          </template>
        </v-data-table>
      </v-card>
    </AsyncState>

    <!-- 詳細パネル -->
    <v-card v-if="selectedCardSet" data-testid="card-set-detail">
      <v-card-title class="d-flex align-center">
        カードセット詳細
        <v-spacer></v-spacer>
        <v-btn
          icon="mdi-close"
          variant="text"
          size="small"
          aria-label="詳細を閉じる"
          @click="selectedCardSet = null"
        />
      </v-card-title>
      <v-card-text>
        <v-row>
          <v-col cols="12" sm="4"><strong>セット名:</strong> {{ selectedCardSet.name }}</v-col>
          <v-col cols="12" sm="4"><strong>年度:</strong> {{ selectedCardSet.year }}</v-col>
          <v-col cols="12" sm="4"><strong>種別:</strong> {{ selectedCardSet.set_type }}</v-col>
        </v-row>
      </v-card-text>
    </v-card>
  </PageLayout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'
import { useSnackbar } from '@/composables/useSnackbar'
import AsyncState from '@/components/shared/AsyncState.vue'
import PageLayout from '@/components/shared/PageLayout.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'
import { tableCell } from '@/components/shared/tableCells'

interface CardSet {
  id: number
  year: number
  set_type: string
  name: string
}

const { showSnackbar } = useSnackbar()

const cardSets = ref<CardSet[]>([])
const loading = ref(true)
const fetchFailed = ref(false)
const selectedCardSet = ref<CardSet | null>(null)

const headers = [
  { title: 'ID', key: 'id', width: '80px', cellProps: tableCell.lead },
  { title: '年度', key: 'year', cellProps: tableCell.sub1 },
  { title: '種別', key: 'set_type', cellProps: tableCell.sub2 },
  { title: 'セット名', key: 'name', cellProps: tableCell.title },
  { title: '操作', key: 'actions', sortable: false, width: '80px', cellProps: tableCell.act },
]

onMounted(fetchCardSets)

async function fetchCardSets() {
  loading.value = true
  fetchFailed.value = false
  try {
    const response = await axios.get<CardSet[]>('/card_sets')
    cardSets.value = response.data
  } catch (error) {
    fetchFailed.value = true
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
    showSnackbar('カードセット詳細の取得に失敗しました', 'error')
    console.error('Error fetching card set detail:', error)
  }
}
</script>
