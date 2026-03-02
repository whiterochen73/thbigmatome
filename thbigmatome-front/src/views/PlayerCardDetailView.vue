<template>
  <v-container style="max-width: 1080px">
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

    <!-- 戻るボタン -->
    <button class="detail-back-btn" @click="router.back()">← 一覧に戻る</button>

    <template v-if="card">
      <div class="detail-wrap">
        <!-- カードヘッダー (藍色帯) -->
        <div class="detail-card-header">
          <div>
            <div class="detail-player-name">#{{ card.player?.number }} {{ card.player?.name }}</div>
            <div class="detail-player-sub">{{ card.card_set?.name }} ／ {{ card.handedness }}</div>
          </div>
          <span class="type-chip-header" :class="card.card_type">
            {{ card.card_type === 'pitcher' ? '投手' : '野手' }}
          </span>
          <div style="flex: 1"></div>
          <span class="header-badge">選手カード詳細</span>
        </div>

        <div class="detail-body">
          <!-- 基本情報セクションヘッダー -->
          <div class="section-header-row">
            <span class="section-header-title">基本情報</span>
            <v-btn
              size="x-small"
              variant="outlined"
              prepend-icon="mdi-pencil"
              @click="openBasicEditDialog"
              >編集</v-btn
            >
          </div>

          <!-- 上段: 画像 + 基本情報グリッド -->
          <div class="detail-top">
            <!-- カード画像 -->
            <div class="card-img-wrap">
              <v-img
                v-if="card.image_url || card.card_image_path"
                :src="card.image_url || imageBaseUrl + card.card_image_path"
                width="108"
                height="150"
                cover
                class="rounded"
              ></v-img>
              <div v-else class="card-img-placeholder">
                <v-icon size="36" color="#9a8060">mdi-card-account-details</v-icon>
                <span>カード画像</span>
              </div>
            </div>

            <!-- 基本情報グリッド -->
            <div class="basic-info-grid">
              <div class="info-item">
                <div class="info-label">走力</div>
                <div class="info-val">{{ card.speed }}</div>
              </div>
              <div class="info-item">
                <div class="info-label">バント</div>
                <div class="info-val">{{ card.bunt }}</div>
              </div>
              <div class="info-item">
                <div class="info-label">盗塁開始</div>
                <div class="info-val">{{ card.steal_start }}</div>
              </div>
              <div class="info-item">
                <div class="info-label">盗塁終了</div>
                <div class="info-val">{{ card.steal_end }}</div>
              </div>
              <div class="info-item">
                <div class="info-label">怪我レベル</div>
                <div class="info-val">{{ card.injury_rate }}</div>
              </div>
              <div class="info-item">
                <div class="info-label">利き腕/打席</div>
                <div class="info-val">{{ card.handedness || '—' }}</div>
              </div>
              <template v-if="card.card_type === 'pitcher'">
                <div class="info-item">
                  <div class="info-label">先発スタミナ</div>
                  <div class="info-val">{{ card.starter_stamina ?? '—' }}</div>
                </div>
                <div class="info-item">
                  <div class="info-label">リリーフ</div>
                  <div class="info-val">{{ card.relief_stamina ?? '—' }}</div>
                </div>
              </template>
              <div class="info-item" v-if="card.biorhythm_period">
                <div class="info-label">バイオリズム</div>
                <div class="info-val">{{ card.biorhythm_period }}</div>
              </div>

              <!-- フラグチップ -->
              <div class="flag-row">
                <span v-if="card.is_closer" class="flag-chip chip-closer">クローザー</span>
                <span v-if="card.is_relief_only" class="flag-chip chip-relief">リリーフ専任</span>
                <span v-if="card.is_switch_hitter" class="flag-chip chip-switch">スイッチ</span>
                <span v-if="card.is_dual_wielder" class="flag-chip chip-dual">二刀流</span>
              </div>
            </div>
          </div>

          <!-- 中段: 守備値 + 特徴・能力 -->
          <div class="detail-mid">
            <!-- 守備値 -->
            <div class="section-box defense-box">
              <div class="section-title-bar">
                🏟 守備値
                <v-btn size="x-small" variant="text" @click="openDefenseEditDialog" class="ml-auto"
                  >編集</v-btn
                >
              </div>
              <div v-if="card.defenses && card.defenses.length > 0" class="section-body pa-1">
                <table class="def-table">
                  <thead>
                    <tr>
                      <th>ポジション</th>
                      <th>範囲</th>
                      <th>エラー</th>
                      <th>送球</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="d in card.defenses" :key="d.id">
                      <td>{{ d.position }}</td>
                      <td>{{ d.range_value }}</td>
                      <td>{{ d.error_rank }}</td>
                      <td>{{ d.throwing ?? '—' }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <div v-else class="section-body text-grey text-caption pa-2">守備値なし</div>
            </div>

            <!-- 特徴・能力 -->
            <div class="section-box">
              <div class="section-title-bar">
                ✨ 特徴・能力
                <v-btn size="x-small" variant="text" @click="openTraitEditDialog" class="ml-auto"
                  >編集</v-btn
                >
              </div>
              <div class="section-body">
                <template v-if="card.trait_list && card.trait_list.length > 0">
                  <span class="chip-section-label">特徴</span>
                  <div class="trait-chips">
                    <span
                      v-for="t in card.trait_list"
                      :key="t.id"
                      class="trait-chip"
                      :title="traitTooltip(t)"
                    >
                      <template v-if="t.condition_name">
                        <span class="condition-text">{{ t.condition_name }}/</span>
                      </template>
                      {{ t.name }}
                    </span>
                  </div>
                </template>
                <template v-if="card.ability_list && card.ability_list.length > 0">
                  <span class="chip-section-label">能力</span>
                  <div class="trait-chips mt-1">
                    <span
                      v-for="a in card.ability_list"
                      :key="a.id"
                      class="ability-chip"
                      :title="a.description ?? ''"
                    >
                      <template v-if="a.condition_name">
                        <span class="condition-text">{{ a.condition_name }}/</span>
                      </template>
                      {{ a.name }}
                    </span>
                  </div>
                </template>
                <div
                  v-if="
                    (!card.trait_list || !card.trait_list.length) &&
                    (!card.ability_list || !card.ability_list.length)
                  "
                  class="text-grey text-caption"
                >
                  特徴・能力なし
                </div>
                <template v-if="card.unique_traits">
                  <div class="unique-traits-box mt-2">{{ card.unique_traits }}</div>
                </template>
                <template v-if="card.injury_traits">
                  <div class="chip-section-label mt-2">怪我特徴</div>
                  <pre class="text-caption text-wrap">{{
                    JSON.stringify(card.injury_traits, null, 2)
                  }}</pre>
                </template>
              </div>
            </div>
          </div>

          <!-- 投球P列 (投手のみ) -->
          <div
            v-if="
              card.card_type === 'pitcher' && card.pitching_table && card.pitching_table.length > 0
            "
            class="section-box mb-2"
          >
            <div class="section-title-bar">
              🎯 投球P列（{{ card.pitching_table.length }}スロット）
            </div>
            <div class="section-body">
              <div class="pitch-bar">
                <div
                  v-for="(p, idx) in card.pitching_table"
                  :key="idx"
                  class="pitch-cell"
                  :class="pitchCellClass(String(p))"
                >
                  <span class="p-idx">P{{ idx + 1 }}</span>
                  {{ p }}
                </div>
              </div>
            </div>
          </div>

          <!-- 打撃結果表 -->
          <div v-if="card.batting_table && card.batting_table.length > 0" class="section-box">
            <div class="section-title-bar">
              🎲 打撃結果表（{{ card.batting_table.length }}行 ×
              {{ card.batting_table[0].length }}列）
            </div>
            <div class="section-body pa-1">
              <div class="overflow-x-auto">
                <BattingTable :table="card.batting_table" />
              </div>
            </div>
          </div>
        </div>
        <!-- /detail-body -->
      </div>
      <!-- /detail-wrap -->
    </template>

    <!-- ■ 基本情報編集ダイアログ -->
    <v-dialog v-model="basicEditDialog" max-width="600">
      <v-card>
        <v-card-title>基本情報を編集</v-card-title>
        <v-card-text>
          <v-row dense>
            <v-col cols="6">
              <v-select
                v-model="basicForm.card_type"
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
                v-model="basicForm.handedness"
                label="利き腕/打席（右/左/両）"
                density="compact"
              ></v-text-field>
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model.number="basicForm.speed"
                label="走力 (1-5)"
                type="number"
                density="compact"
                :rules="[(v) => (v >= 1 && v <= 5) || '1-5で入力']"
              ></v-text-field>
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model.number="basicForm.bunt"
                label="バント (1-10)"
                type="number"
                density="compact"
              ></v-text-field>
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model.number="basicForm.steal_start"
                label="盗塁開始"
                type="number"
                density="compact"
              ></v-text-field>
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model.number="basicForm.steal_end"
                label="盗塁終了"
                type="number"
                density="compact"
              ></v-text-field>
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model.number="basicForm.injury_rate"
                label="怪我レベル (0-7)"
                type="number"
                density="compact"
                :rules="[(v) => (v >= 0 && v <= 7) || '0-7で入力']"
              ></v-text-field>
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model="basicForm.biorhythm_period"
                label="バイオリズム"
                density="compact"
              ></v-text-field>
            </v-col>
            <template v-if="basicForm.card_type === 'pitcher'">
              <v-col cols="6">
                <v-text-field
                  v-model.number="basicForm.starter_stamina"
                  label="先発スタミナ (4-9)"
                  type="number"
                  density="compact"
                ></v-text-field>
              </v-col>
              <v-col cols="6">
                <v-text-field
                  v-model.number="basicForm.relief_stamina"
                  label="リリーフスタミナ (0-3)"
                  type="number"
                  density="compact"
                ></v-text-field>
              </v-col>
            </template>
            <v-col cols="12" class="d-flex flex-wrap gap-4">
              <v-switch
                v-model="basicForm.is_relief_only"
                label="リリーフ専任"
                density="compact"
                hide-details
              ></v-switch>
              <v-switch
                v-model="basicForm.is_closer"
                label="クローザー"
                density="compact"
                hide-details
              ></v-switch>
              <v-switch
                v-model="basicForm.is_switch_hitter"
                label="スイッチ"
                density="compact"
                hide-details
              ></v-switch>
              <v-switch
                v-model="basicForm.is_dual_wielder"
                label="二刀流"
                density="compact"
                hide-details
              ></v-switch>
            </v-col>
          </v-row>
          <v-alert v-if="editError" type="error" variant="tonal" class="mt-2">
            {{ editError }}
          </v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn @click="basicEditDialog = false">キャンセル</v-btn>
          <v-btn color="primary" :loading="saving" @click="saveBasicInfo">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ■ 守備値編集ダイアログ -->
    <v-dialog v-model="defenseEditDialog" max-width="700">
      <v-card>
        <v-card-title>守備値を編集</v-card-title>
        <v-card-text>
          <v-table density="compact">
            <thead>
              <tr>
                <th>ポジション</th>
                <th>範囲</th>
                <th>エラーランク</th>
                <th>送球</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(d, idx) in defenseForm" :key="idx">
                <td>
                  <v-text-field
                    v-model="d.position"
                    density="compact"
                    hide-details
                    variant="underlined"
                    style="min-width: 60px"
                  ></v-text-field>
                </td>
                <td>
                  <v-text-field
                    v-model.number="d.range_value"
                    type="number"
                    density="compact"
                    hide-details
                    variant="underlined"
                    style="min-width: 60px"
                  ></v-text-field>
                </td>
                <td>
                  <v-text-field
                    v-model="d.error_rank"
                    density="compact"
                    hide-details
                    variant="underlined"
                    style="min-width: 60px"
                  ></v-text-field>
                </td>
                <td>
                  <v-text-field
                    v-model="d.throwing"
                    density="compact"
                    hide-details
                    variant="underlined"
                    style="min-width: 60px"
                  ></v-text-field>
                </td>
                <td>
                  <v-btn
                    icon
                    size="x-small"
                    color="error"
                    variant="text"
                    @click="removeDefenseRow(idx)"
                  >
                    <v-icon>mdi-delete</v-icon>
                  </v-btn>
                </td>
              </tr>
            </tbody>
          </v-table>
          <v-btn size="small" prepend-icon="mdi-plus" class="mt-2" @click="addDefenseRow"
            >行を追加</v-btn
          >
          <v-alert v-if="editError" type="error" variant="tonal" class="mt-2">
            {{ editError }}
          </v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn @click="defenseEditDialog = false">キャンセル</v-btn>
          <v-btn color="primary" :loading="saving" @click="saveDefenses">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ■ 特徴・能力編集ダイアログ -->
    <v-dialog v-model="traitEditDialog" max-width="700">
      <v-card>
        <v-card-title>特徴・能力を編集</v-card-title>
        <v-card-text>
          <!-- 特徴 -->
          <div class="text-subtitle-2 mb-2">特徴</div>
          <div class="d-flex flex-wrap gap-1 mb-2">
            <v-chip
              v-for="(t, idx) in traitForm"
              :key="idx"
              closable
              @click:close="removeTrait(idx)"
              size="small"
            >
              <template v-if="t.condition_name">{{ t.condition_name }}/</template>{{ t.name }}
            </v-chip>
          </div>
          <v-row dense>
            <v-col cols="5">
              <v-text-field
                v-model.number="newTraitDefId"
                label="特徴定義ID"
                type="number"
                density="compact"
                hide-details
              ></v-text-field>
            </v-col>
            <v-col cols="4">
              <v-text-field
                v-model="newTraitRole"
                label="ロール"
                density="compact"
                hide-details
              ></v-text-field>
            </v-col>
            <v-col cols="3">
              <v-btn size="small" prepend-icon="mdi-plus" @click="addTrait">追加</v-btn>
            </v-col>
          </v-row>

          <v-divider class="my-3"></v-divider>

          <!-- 能力 -->
          <div class="text-subtitle-2 mb-2">能力</div>
          <div class="d-flex flex-wrap gap-1 mb-2">
            <v-chip
              v-for="(a, idx) in abilityForm"
              :key="idx"
              closable
              @click:close="removeAbility(idx)"
              size="small"
              color="blue-grey"
              variant="tonal"
            >
              <template v-if="a.condition_name">{{ a.condition_name }}/</template>{{ a.name }}
            </v-chip>
          </div>
          <v-row dense>
            <v-col cols="5">
              <v-text-field
                v-model.number="newAbilityDefId"
                label="能力定義ID"
                type="number"
                density="compact"
                hide-details
              ></v-text-field>
            </v-col>
            <v-col cols="4">
              <v-text-field
                v-model="newAbilityRole"
                label="ロール"
                density="compact"
                hide-details
              ></v-text-field>
            </v-col>
            <v-col cols="3">
              <v-btn size="small" prepend-icon="mdi-plus" @click="addAbility">追加</v-btn>
            </v-col>
          </v-row>

          <v-divider class="my-3"></v-divider>

          <!-- 固有特徴 -->
          <div class="text-subtitle-2 mb-2">固有特徴 (unique_traits)</div>
          <v-textarea
            v-model="uniqueTraitsForm"
            density="compact"
            rows="3"
            hide-details
          ></v-textarea>

          <v-alert v-if="editError" type="error" variant="tonal" class="mt-2">
            {{ editError }}
          </v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn @click="traitEditDialog = false">キャンセル</v-btn>
          <v-btn color="primary" :loading="saving" @click="saveTraits">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from '@/plugins/axios'
import BattingTable from '@/components/BattingTable.vue'

interface DefenseItem {
  id?: number
  position: string
  range_value: number
  error_rank: string
  throwing: string | null
}

interface TraitItem {
  id?: number
  name: string
  description: string | null
  role: string | null
  condition_name: string | null
  condition_description: string | null
  trait_definition_id?: number
  category?: string | null
}

interface AbilityItem {
  id?: number
  name: string
  description: string | null
  role: string | null
  condition_name: string | null
  condition_description: string | null
  ability_definition_id?: number
}

interface PlayerCardDetail {
  id: number
  card_type: 'pitcher' | 'batter'
  handedness: string | null
  speed: number
  bunt: number
  steal_start: number
  steal_end: number
  injury_rate: number
  is_pitcher: boolean
  is_relief_only: boolean
  is_closer: boolean
  is_switch_hitter: boolean
  is_dual_wielder: boolean
  starter_stamina: number | null
  relief_stamina: number | null
  biorhythm_period: string | null
  unique_traits: string | null
  injury_traits: Record<string, unknown> | null
  card_image_path: string | null
  image_url: string | null
  player: { id: number; name: string; number: string } | null
  card_set: { id: number; name: string } | null
  defenses: DefenseItem[]
  trait_list: TraitItem[]
  ability_list: AbilityItem[]
  batting_table: string[][]
  pitching_table: string[]
}

const imageBaseUrl = computed(() => {
  return axios.defaults.baseURL?.replace(/\/api\/v1\/?$/, '') || ''
})

const route = useRoute()
const router = useRouter()
const card = ref<PlayerCardDetail | null>(null)
const loading = ref(false)
const errorMessage = ref('')
const saving = ref(false)
const editError = ref('')

// --- Basic edit dialog ---
const basicEditDialog = ref(false)
const basicForm = ref({
  card_type: 'batter' as 'pitcher' | 'batter',
  handedness: '' as string | null,
  speed: 3,
  bunt: 5,
  steal_start: 10,
  steal_end: 10,
  injury_rate: 3,
  biorhythm_period: '' as string | null,
  starter_stamina: null as number | null,
  relief_stamina: null as number | null,
  is_relief_only: false,
  is_closer: false,
  is_switch_hitter: false,
  is_dual_wielder: false,
})

// --- Defense edit dialog ---
const defenseEditDialog = ref(false)
const defenseForm = ref<DefenseItem[]>([])
const deletedDefenseIds = ref<number[]>([])

// --- Trait edit dialog ---
const traitEditDialog = ref(false)
const traitForm = ref<TraitItem[]>([])
const abilityForm = ref<AbilityItem[]>([])
const deletedTraitIds = ref<number[]>([])
const deletedAbilityIds = ref<number[]>([])
const newTraitDefId = ref<number | null>(null)
const newTraitRole = ref('')
const newAbilityDefId = ref<number | null>(null)
const newAbilityRole = ref('')
const uniqueTraitsForm = ref('')

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

// ---- Trait tooltip helper ----
function traitTooltip(t: TraitItem): string {
  const parts = []
  if (t.condition_description) parts.push(`条件: ${t.condition_description}`)
  if (t.description) parts.push(t.description)
  return parts.join('\n')
}

// ---- Pitching cell class (prototype準拠) ----
function pitchCellClass(val: string): string {
  if (val.includes('*')) return 'p-cell-wp'
  const n = parseInt(val)
  if (n >= 1 && n <= 5) return `p-cell-${n}`
  return 'p-cell-6'
}

// ---- Basic info ----
function openBasicEditDialog() {
  if (!card.value) return
  basicForm.value = {
    card_type: card.value.card_type,
    handedness: card.value.handedness,
    speed: card.value.speed,
    bunt: card.value.bunt,
    steal_start: card.value.steal_start,
    steal_end: card.value.steal_end,
    injury_rate: card.value.injury_rate,
    biorhythm_period: card.value.biorhythm_period,
    starter_stamina: card.value.starter_stamina,
    relief_stamina: card.value.relief_stamina,
    is_relief_only: card.value.is_relief_only,
    is_closer: card.value.is_closer,
    is_switch_hitter: card.value.is_switch_hitter,
    is_dual_wielder: card.value.is_dual_wielder,
  }
  editError.value = ''
  basicEditDialog.value = true
}

async function saveBasicInfo() {
  saving.value = true
  editError.value = ''
  try {
    const id = route.params.id
    const response = await axios.patch<PlayerCardDetail>(`/player_cards/${id}`, {
      player_card: basicForm.value,
    })
    card.value = response.data
    basicEditDialog.value = false
  } catch (error: unknown) {
    editError.value = extractErrorMessage(error)
  } finally {
    saving.value = false
  }
}

// ---- Defense ----
function openDefenseEditDialog() {
  if (!card.value) return
  defenseForm.value = card.value.defenses.map((d) => ({ ...d }))
  deletedDefenseIds.value = []
  editError.value = ''
  defenseEditDialog.value = true
}

function addDefenseRow() {
  defenseForm.value.push({ position: '', range_value: 3, error_rank: 'B', throwing: null })
}

function removeDefenseRow(idx: number) {
  const d = defenseForm.value[idx]
  if (d.id) deletedDefenseIds.value.push(d.id)
  defenseForm.value.splice(idx, 1)
}

async function saveDefenses() {
  saving.value = true
  editError.value = ''
  try {
    const id = route.params.id
    const attrs = [
      ...defenseForm.value.map((d) => ({
        id: d.id,
        position: d.position,
        range_value: d.range_value,
        error_rank: d.error_rank,
        throwing: d.throwing || null,
      })),
      ...deletedDefenseIds.value.map((did) => ({ id: did, _destroy: true })),
    ]
    const response = await axios.patch<PlayerCardDetail>(`/player_cards/${id}`, {
      player_card: { player_card_defenses_attributes: attrs },
    })
    card.value = response.data
    defenseEditDialog.value = false
  } catch (error: unknown) {
    editError.value = extractErrorMessage(error)
  } finally {
    saving.value = false
  }
}

// ---- Traits & Abilities ----
function openTraitEditDialog() {
  if (!card.value) return
  traitForm.value = card.value.trait_list.map((t) => ({ ...t }))
  abilityForm.value = card.value.ability_list.map((a) => ({ ...a }))
  deletedTraitIds.value = []
  deletedAbilityIds.value = []
  uniqueTraitsForm.value = card.value.unique_traits ?? ''
  newTraitDefId.value = null
  newTraitRole.value = ''
  newAbilityDefId.value = null
  newAbilityRole.value = ''
  editError.value = ''
  traitEditDialog.value = true
}

function addTrait() {
  if (!newTraitDefId.value) return
  traitForm.value.push({
    trait_definition_id: newTraitDefId.value,
    name: `定義ID:${newTraitDefId.value}`,
    description: null,
    role: newTraitRole.value || null,
    condition_name: null,
    condition_description: null,
  })
  newTraitDefId.value = null
  newTraitRole.value = ''
}

function removeTrait(idx: number) {
  const t = traitForm.value[idx]
  if (t.id) deletedTraitIds.value.push(t.id)
  traitForm.value.splice(idx, 1)
}

function addAbility() {
  if (!newAbilityDefId.value) return
  abilityForm.value.push({
    ability_definition_id: newAbilityDefId.value,
    name: `定義ID:${newAbilityDefId.value}`,
    description: null,
    role: newAbilityRole.value || null,
    condition_name: null,
    condition_description: null,
  })
  newAbilityDefId.value = null
  newAbilityRole.value = ''
}

function removeAbility(idx: number) {
  const a = abilityForm.value[idx]
  if (a.id) deletedAbilityIds.value.push(a.id)
  abilityForm.value.splice(idx, 1)
}

async function saveTraits() {
  saving.value = true
  editError.value = ''
  try {
    const id = route.params.id
    const traitAttrs = [
      ...traitForm.value
        .filter((t) => !t.id)
        .map((t) => ({
          trait_definition_id: t.trait_definition_id,
          role: t.role,
        })),
      ...deletedTraitIds.value.map((tid) => ({ id: tid, _destroy: true })),
    ]
    const abilityAttrs = [
      ...abilityForm.value
        .filter((a) => !a.id)
        .map((a) => ({
          ability_definition_id: a.ability_definition_id,
          role: a.role,
        })),
      ...deletedAbilityIds.value.map((aid) => ({ id: aid, _destroy: true })),
    ]
    const response = await axios.patch<PlayerCardDetail>(`/player_cards/${id}`, {
      player_card: {
        unique_traits: uniqueTraitsForm.value || null,
        player_card_traits_attributes: traitAttrs,
        player_card_abilities_attributes: abilityAttrs,
      },
    })
    card.value = response.data
    traitEditDialog.value = false
  } catch (error: unknown) {
    editError.value = extractErrorMessage(error)
  } finally {
    saving.value = false
  }
}

// ---- Utilities ----
function extractErrorMessage(error: unknown): string {
  if (
    error &&
    typeof error === 'object' &&
    'response' in error &&
    error.response &&
    typeof error.response === 'object' &&
    'data' in error.response
  ) {
    const data = error.response.data as { errors?: string[] }
    return data.errors?.join(', ') || '保存に失敗しました'
  }
  return '保存に失敗しました'
}
</script>

<style scoped>
/* ── 戻るボタン ── */
.detail-back-btn {
  background: none;
  border: 1px solid #bbb;
  padding: 3px 10px;
  border-radius: 3px;
  cursor: pointer;
  font-size: 0.79em;
  margin-bottom: 8px;
  color: #555;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.detail-back-btn:hover {
  background: #e8e0d4;
  border-color: #999;
}

/* ── 詳細ラッパー ── */
.detail-wrap {
  background: white;
  border: 1px solid #ddd;
  border-radius: 6px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.1);
}

/* ── カードヘッダー (藍色帯) ── */
.detail-card-header {
  background: var(--ai);
  color: white;
  padding: 7px 14px;
  display: flex;
  align-items: center;
  gap: 10px;
}

.detail-player-name {
  font-size: 1.05em;
  font-weight: bold;
}

.detail-player-sub {
  font-size: 0.76em;
  opacity: 0.75;
  margin-top: 1px;
}

.header-badge {
  font-size: 0.72em;
  opacity: 0.6;
}

.type-chip-header {
  padding: 2px 9px;
  border-radius: 10px;
  font-size: 0.75em;
  font-weight: bold;
  display: inline-block;
}

.type-chip-header.pitcher {
  background: rgba(219, 234, 254, 0.85);
  color: #1e40af;
}

.type-chip-header.batter {
  background: rgba(220, 252, 231, 0.85);
  color: #166534;
}

/* ── デタイルボディ ── */
.detail-body {
  padding: 10px 14px;
}

/* ── セクションヘッダー行 ── */
.section-header-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}

.section-header-title {
  font-size: 0.85em;
  font-weight: bold;
  color: #5a3e20;
  background: #ece4d8;
  padding: 3px 10px;
  border-radius: 3px;
}

/* ── 上段: 画像 + 基本情報 ── */
.detail-top {
  display: flex;
  gap: 12px;
  margin-bottom: 10px;
}

.card-img-wrap {
  flex-shrink: 0;
  width: 108px;
}

.card-img-placeholder {
  width: 108px;
  height: 150px;
  background: linear-gradient(160deg, #e8e0d4 0%, #d0c0a8 100%);
  border: 2px solid var(--usuiro);
  border-radius: 4px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: #9a8060;
  font-size: 0.73em;
  text-align: center;
  gap: 4px;
}

.basic-info-grid {
  flex: 1;
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 4px 10px;
  align-content: start;
}

.info-item {
}

.info-label {
  font-size: 0.68em;
  color: #999;
  line-height: 1.2;
}

.info-val {
  font-size: 0.9em;
  font-weight: bold;
  color: #222;
}

.flag-row {
  grid-column: 1 / -1;
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: 4px;
}

.flag-chip {
  padding: 1px 7px;
  border-radius: 8px;
  font-size: 0.71em;
  font-weight: bold;
}

.chip-closer {
  background: #fed7aa;
  color: #9a3412;
  border: 1px solid #fdba74;
}

.chip-relief {
  background: #e9d5ff;
  color: #6b21a8;
  border: 1px solid #d8b4fe;
}

.chip-switch {
  background: #ccfbf1;
  color: #0f766e;
  border: 1px solid #99f6e4;
}

.chip-dual {
  background: #ffedd5;
  color: #c2410c;
  border: 1px solid #fed7aa;
}

/* ── 中段: 守備値 + 特徴 ── */
.detail-mid {
  display: flex;
  gap: 8px;
  margin-bottom: 8px;
}

.section-box {
  border: 1px solid #e0d8cc;
  border-radius: 4px;
  overflow: hidden;
  flex: 1;
}

.defense-box {
  flex: 0 0 260px;
}

.section-title-bar {
  background: #ece4d8;
  color: #5a3e20;
  padding: 4px 10px;
  font-size: 0.74em;
  font-weight: bold;
  letter-spacing: 0.04em;
  border-bottom: 1px solid #d4c5a9;
  display: flex;
  align-items: center;
}

.section-body {
  padding: 6px 8px;
}

/* ── 守備テーブル ── */
.def-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.8em;
}

.def-table th {
  padding: 2px 6px;
  text-align: center;
  color: #999;
  font-size: 0.82em;
  font-weight: normal;
  border-bottom: 1px solid #eee;
  white-space: nowrap;
}

.def-table th:first-child {
  text-align: left;
}

.def-table td {
  padding: 2px 6px;
  text-align: center;
  border-bottom: 1px solid #f4f0ea;
}

.def-table td:first-child {
  text-align: left;
  font-weight: bold;
}

.def-table tr:last-child td {
  border-bottom: none;
}

/* ── 特徴チップ ── */
.trait-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 3px;
}

.trait-chip {
  background: #f0e8d8;
  border: 1px solid var(--usuiro);
  padding: 2px 7px;
  border-radius: 3px;
  font-size: 0.75em;
  color: #4a3010;
  cursor: default;
}

.ability-chip {
  background: #ede9f4;
  border: 1px solid #c5b8d9;
  padding: 2px 7px;
  border-radius: 3px;
  font-size: 0.75em;
  color: #4a2a6a;
}

.chip-section-label {
  font-size: 0.67em;
  color: #aaa;
  display: block;
  margin: 4px 0 2px;
}

.condition-text {
  color: #888;
}

.unique-traits-box {
  font-size: 0.76em;
  color: #6a4a20;
  background: #faf5ec;
  border: 1px solid #e0d4bc;
  border-radius: 3px;
  padding: 4px 7px;
}

/* ── 投球P列 ── */
.pitch-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 3px;
  padding: 4px 0;
}

.pitch-cell {
  min-width: 34px;
  padding: 2px 4px;
  text-align: center;
  border-radius: 3px;
  font-size: 0.76em;
  font-weight: bold;
  border: 1px solid;
  position: relative;
}

.p-idx {
  font-size: 0.62em;
  color: #aaa;
  display: block;
  line-height: 1;
  margin-bottom: 1px;
}

.p-cell-1 {
  background: #dbeafe;
  border-color: #93c5fd;
  color: #1e40af;
}
.p-cell-2 {
  background: #d1fae5;
  border-color: #6ee7b7;
  color: #065f46;
}
.p-cell-3 {
  background: #fef9c3;
  border-color: #fde047;
  color: #713f12;
}
.p-cell-4 {
  background: #ffe4e6;
  border-color: #fda4af;
  color: #9f1239;
}
.p-cell-5 {
  background: #f3e8ff;
  border-color: #d8b4fe;
  color: #6b21a8;
}
.p-cell-6 {
  background: #ffedd5;
  border-color: #fdba74;
  color: #9a3412;
}
.p-cell-wp {
  background: #fed7aa;
  border-color: #fb923c;
  color: #9a3412;
  font-style: italic;
}
</style>
