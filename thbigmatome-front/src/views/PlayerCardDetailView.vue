<template>
  <v-container>
    <v-row>
      <v-col cols="12" class="d-flex align-center">
        <v-btn icon variant="text" @click="router.back()">
          <v-icon>mdi-arrow-left</v-icon>
        </v-btn>
        <h1 class="text-h5 ml-2">選手カード詳細</h1>
        <v-spacer></v-spacer>
        <v-btn color="primary" @click="openEditDialog" prepend-icon="mdi-pencil">編集</v-btn>
      </v-col>
    </v-row>

    <v-progress-linear
      v-if="loading"
      indeterminate
      color="primary"
      class="mb-3"
    ></v-progress-linear>

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

    <template v-if="card">
      <v-row>
        <!-- カード画像 -->
        <v-col cols="12" sm="3" class="text-center">
          <v-img
            v-if="card.image_url || card.card_image_path"
            :src="card.image_url || `http://localhost:3000${card.card_image_path}`"
            max-width="200"
            class="mx-auto rounded"
          ></v-img>
          <v-card v-else width="140" class="mx-auto" variant="outlined" height="200">
            <v-card-text class="d-flex align-center justify-center fill-height text-grey">
              <v-icon size="64">mdi-card-account-details</v-icon>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- 基本情報 -->
        <v-col cols="12" sm="9">
          <v-card variant="outlined">
            <v-card-title class="text-subtitle-1">基本情報</v-card-title>
            <v-card-text>
              <v-row dense>
                <v-col cols="6" sm="3">
                  <div class="text-caption text-grey">選手名</div>
                  <div>{{ card.player?.name }}</div>
                </v-col>
                <v-col cols="6" sm="3">
                  <div class="text-caption text-grey">背番号</div>
                  <div>{{ card.player?.number }}</div>
                </v-col>
                <v-col cols="6" sm="3">
                  <div class="text-caption text-grey">カードセット</div>
                  <div>{{ card.card_set?.name }}</div>
                </v-col>
                <v-col cols="6" sm="3">
                  <div class="text-caption text-grey">種別</div>
                  <v-chip
                    :color="card.card_type === 'pitcher' ? 'blue' : 'green'"
                    size="small"
                    label
                  >
                    {{ card.card_type === 'pitcher' ? '投手' : '野手' }}
                  </v-chip>
                </v-col>
                <v-col cols="6" sm="3">
                  <div class="text-caption text-grey">走力</div>
                  <div>{{ card.speed }}</div>
                </v-col>
                <v-col cols="6" sm="3">
                  <div class="text-caption text-grey">盗塁開始</div>
                  <div>{{ card.steal_start }}</div>
                </v-col>
                <v-col cols="6" sm="3">
                  <div class="text-caption text-grey">盗塁終了</div>
                  <div>{{ card.steal_end }}</div>
                </v-col>
                <v-col cols="6" sm="3">
                  <div class="text-caption text-grey">怪我レベル</div>
                  <div>{{ card.injury_rate }}</div>
                </v-col>
                <v-col cols="6" sm="3" v-if="card.card_type === 'pitcher'">
                  <div class="text-caption text-grey">先発スタミナ</div>
                  <div>{{ card.starter_stamina ?? '-' }}</div>
                </v-col>
                <v-col cols="6" sm="3" v-if="card.card_type === 'pitcher'">
                  <div class="text-caption text-grey">リリーフスタミナ</div>
                  <div>{{ card.relief_stamina ?? '-' }}</div>
                </v-col>
                <v-col cols="6" sm="3" v-if="card.is_relief_only">
                  <div class="text-caption text-grey">リリーフ専任</div>
                  <v-icon color="green">mdi-check</v-icon>
                </v-col>
              </v-row>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <v-row class="mt-2">
        <!-- 守備値 -->
        <v-col cols="12" sm="6" v-if="card.defenses && card.defenses.length > 0">
          <v-card variant="outlined">
            <v-card-title class="text-subtitle-1">守備値</v-card-title>
            <v-card-text class="pa-0">
              <v-table density="compact">
                <thead>
                  <tr>
                    <th>ポジション</th>
                    <th>範囲</th>
                    <th>エラー</th>
                    <th>送球</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="d in card.defenses" :key="d.position">
                    <td>{{ d.position }}</td>
                    <td>{{ d.range_value }}</td>
                    <td>{{ d.error_rank }}</td>
                    <td>{{ d.throwing ?? '-' }}</td>
                  </tr>
                </tbody>
              </v-table>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- 特徴 -->
        <v-col cols="12" sm="6" v-if="card.trait_list && card.trait_list.length > 0">
          <v-card variant="outlined">
            <v-card-title class="text-subtitle-1">特徴</v-card-title>
            <v-card-text>
              <v-chip
                v-for="t in card.trait_list"
                :key="t.name"
                class="mr-1 mb-1"
                size="small"
                :title="t.description"
              >
                {{ t.name }}
              </v-chip>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <!-- 固有特徴・怪我特徴 -->
      <v-row class="mt-0">
        <v-col cols="12" sm="6" v-if="card.unique_traits">
          <v-card variant="outlined">
            <v-card-title class="text-subtitle-1">固有特徴</v-card-title>
            <v-card-text>
              <pre class="text-body-2 text-wrap">{{ card.unique_traits }}</pre>
            </v-card-text>
          </v-card>
        </v-col>
        <v-col cols="12" sm="6" v-if="card.injury_traits">
          <v-card variant="outlined">
            <v-card-title class="text-subtitle-1">怪我特徴</v-card-title>
            <v-card-text>
              <pre class="text-body-2 text-wrap">{{
                JSON.stringify(card.injury_traits, null, 2)
              }}</pre>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- 編集ダイアログ -->
    <v-dialog v-model="editDialog" max-width="500">
      <v-card>
        <v-card-title>基本情報を編集</v-card-title>
        <v-card-text>
          <v-row dense>
            <v-col cols="6">
              <v-select
                v-model="editForm.card_type"
                :items="[
                  { title: '投手', value: 'pitcher' },
                  { title: '野手', value: 'batter' },
                ]"
                item-title="title"
                item-value="value"
                label="種別"
                density="compact"
              ></v-select>
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model.number="editForm.speed"
                label="走力"
                type="number"
                density="compact"
                :rules="[(v) => (v >= 1 && v <= 5) || '1-5で入力']"
              ></v-text-field>
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model.number="editForm.steal_start"
                label="盗塁開始"
                type="number"
                density="compact"
              ></v-text-field>
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model.number="editForm.steal_end"
                label="盗塁終了"
                type="number"
                density="compact"
              ></v-text-field>
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model.number="editForm.injury_rate"
                label="怪我レベル"
                type="number"
                density="compact"
                :rules="[(v) => (v >= 0 && v <= 7) || '0-7で入力']"
              ></v-text-field>
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model.number="editForm.bunt"
                label="バント"
                type="number"
                density="compact"
              ></v-text-field>
            </v-col>
            <template v-if="editForm.card_type === 'pitcher'">
              <v-col cols="6">
                <v-text-field
                  v-model.number="editForm.starter_stamina"
                  label="先発スタミナ"
                  type="number"
                  density="compact"
                ></v-text-field>
              </v-col>
              <v-col cols="6">
                <v-text-field
                  v-model.number="editForm.relief_stamina"
                  label="リリーフスタミナ"
                  type="number"
                  density="compact"
                ></v-text-field>
              </v-col>
            </template>
          </v-row>
          <v-alert v-if="editError" type="error" variant="tonal" class="mt-2">
            {{ editError }}
          </v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn @click="editDialog = false">キャンセル</v-btn>
          <v-btn color="primary" :loading="saving" @click="saveCard">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from '@/plugins/axios'

interface PlayerCardDetail {
  id: number
  card_type: 'pitcher' | 'batter'
  speed: number
  bunt: number
  steal_start: number
  steal_end: number
  injury_rate: number
  is_pitcher: boolean
  is_relief_only: boolean
  starter_stamina: number | null
  relief_stamina: number | null
  unique_traits: string | null
  injury_traits: Record<string, unknown> | null
  card_image_path: string | null
  image_url: string | null
  player: { id: number; name: string; number: string } | null
  card_set: { id: number; name: string } | null
  defenses: Array<{
    position: string
    range_value: number
    error_rank: string
    throwing: string | null
  }>
  trait_list: Array<{
    category: string | null
    name: string
    description: string | null
    role: string | null
  }>
  ability_list: Array<{
    name: string
    description: string | null
    role: string | null
  }>
}

const route = useRoute()
const router = useRouter()
const card = ref<PlayerCardDetail | null>(null)
const loading = ref(false)
const errorMessage = ref('')
const editDialog = ref(false)
const saving = ref(false)
const editError = ref('')

const editForm = ref({
  card_type: 'batter' as 'pitcher' | 'batter',
  speed: 3,
  bunt: 5,
  steal_start: 10,
  steal_end: 10,
  injury_rate: 3,
  starter_stamina: null as number | null,
  relief_stamina: null as number | null,
})

onMounted(() => {
  fetchCard()
})

async function fetchCard() {
  loading.value = true
  errorMessage.value = ''
  try {
    const id = route.params.id
    const response = await axios.get<PlayerCardDetail>(`/player_cards/${id}`)
    card.value = response.data
  } catch (error) {
    errorMessage.value = '選手カードの取得に失敗しました'
    console.error('Error fetching player card:', error)
  } finally {
    loading.value = false
  }
}

function openEditDialog() {
  if (!card.value) return
  editForm.value = {
    card_type: card.value.card_type,
    speed: card.value.speed,
    bunt: card.value.bunt,
    steal_start: card.value.steal_start,
    steal_end: card.value.steal_end,
    injury_rate: card.value.injury_rate,
    starter_stamina: card.value.starter_stamina,
    relief_stamina: card.value.relief_stamina,
  }
  editError.value = ''
  editDialog.value = true
}

async function saveCard() {
  saving.value = true
  editError.value = ''
  try {
    const id = route.params.id
    const response = await axios.patch<PlayerCardDetail>(`/player_cards/${id}`, {
      player_card: editForm.value,
    })
    card.value = response.data
    editDialog.value = false
  } catch (error: unknown) {
    if (
      error &&
      typeof error === 'object' &&
      'response' in error &&
      error.response &&
      typeof error.response === 'object' &&
      'data' in error.response
    ) {
      const data = error.response.data as { errors?: string[] }
      editError.value = data.errors?.join(', ') || '保存に失敗しました'
    } else {
      editError.value = '保存に失敗しました'
    }
    console.error('Error saving player card:', error)
  } finally {
    saving.value = false
  }
}
</script>
