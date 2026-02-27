<template>
  <v-container>
    <v-row>
      <v-col cols="12" class="d-flex align-center">
        <v-btn icon variant="text" @click="router.back()">
          <v-icon>mdi-arrow-left</v-icon>
        </v-btn>
        <h1 class="text-h5 ml-2">選手カード詳細</h1>
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
      <!-- カード画像 + 基本情報 -->
      <v-row>
        <!-- カード画像（大きく表示） -->
        <v-col cols="12" sm="4" class="text-center">
          <v-img
            v-if="card.image_url || card.card_image_path"
            :src="card.image_url || `http://localhost:3000${card.card_image_path}`"
            max-width="400"
            class="mx-auto rounded elevation-2"
          ></v-img>
          <v-card v-else width="240" class="mx-auto" variant="outlined" height="340">
            <v-card-text class="d-flex align-center justify-center fill-height text-grey">
              <v-icon size="80">mdi-card-account-details</v-icon>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- 基本情報 -->
        <v-col cols="12" sm="8">
          <v-card variant="outlined">
            <v-card-title class="text-subtitle-1 d-flex align-center">
              基本情報
              <v-spacer></v-spacer>
              <v-btn
                size="small"
                color="primary"
                variant="text"
                prepend-icon="mdi-pencil"
                @click="openBasicEditDialog"
                >編集</v-btn
              >
            </v-card-title>
            <v-card-text>
              <v-row dense>
                <v-col cols="6" sm="4">
                  <div class="text-caption text-grey">選手名</div>
                  <div>{{ card.player?.name }}</div>
                </v-col>
                <v-col cols="6" sm="4">
                  <div class="text-caption text-grey">背番号</div>
                  <div>{{ card.player?.number }}</div>
                </v-col>
                <v-col cols="6" sm="4">
                  <div class="text-caption text-grey">カードセット</div>
                  <div>{{ card.card_set?.name }}</div>
                </v-col>
                <v-col cols="6" sm="4">
                  <div class="text-caption text-grey">種別</div>
                  <v-chip
                    :color="card.card_type === 'pitcher' ? 'blue' : 'green'"
                    size="small"
                    label
                  >
                    {{ card.card_type === 'pitcher' ? '投手' : '野手' }}
                  </v-chip>
                </v-col>
                <v-col cols="6" sm="4">
                  <div class="text-caption text-grey">利き腕/打席</div>
                  <div>{{ card.handedness || '-' }}</div>
                </v-col>
                <v-col cols="6" sm="4">
                  <div class="text-caption text-grey">走力</div>
                  <div>{{ card.speed }}</div>
                </v-col>
                <v-col cols="6" sm="4">
                  <div class="text-caption text-grey">バント</div>
                  <div>{{ card.bunt }}</div>
                </v-col>
                <v-col cols="6" sm="4">
                  <div class="text-caption text-grey">盗塁開始</div>
                  <div>{{ card.steal_start }}</div>
                </v-col>
                <v-col cols="6" sm="4">
                  <div class="text-caption text-grey">盗塁終了</div>
                  <div>{{ card.steal_end }}</div>
                </v-col>
                <v-col cols="6" sm="4">
                  <div class="text-caption text-grey">怪我レベル</div>
                  <div>{{ card.injury_rate }}</div>
                </v-col>
                <v-col cols="6" sm="4" v-if="card.biorhythm_period">
                  <div class="text-caption text-grey">バイオリズム</div>
                  <div>{{ card.biorhythm_period }}</div>
                </v-col>
                <v-col cols="6" sm="4" v-if="card.card_type === 'pitcher'">
                  <div class="text-caption text-grey">先発スタミナ</div>
                  <div>{{ card.starter_stamina ?? '-' }}</div>
                </v-col>
                <v-col cols="6" sm="4" v-if="card.card_type === 'pitcher'">
                  <div class="text-caption text-grey">リリーフスタミナ</div>
                  <div>{{ card.relief_stamina ?? '-' }}</div>
                </v-col>
                <v-col cols="12" class="d-flex gap-2 flex-wrap mt-1">
                  <v-chip v-if="card.is_closer" color="orange" size="small" label
                    >クローザー</v-chip
                  >
                  <v-chip v-if="card.is_relief_only" color="purple" size="small" label
                    >リリーフ専任</v-chip
                  >
                  <v-chip v-if="card.is_switch_hitter" color="teal" size="small" label
                    >スイッチ</v-chip
                  >
                  <v-chip v-if="card.is_dual_wielder" color="deep-orange" size="small" label
                    >二刀流</v-chip
                  >
                </v-col>
              </v-row>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <v-row class="mt-2">
        <!-- 守備値 -->
        <v-col cols="12" sm="6">
          <v-card variant="outlined">
            <v-card-title class="text-subtitle-1 d-flex align-center">
              守備値
              <v-spacer></v-spacer>
              <v-btn
                size="small"
                color="primary"
                variant="text"
                prepend-icon="mdi-pencil"
                @click="openDefenseEditDialog"
                >編集</v-btn
              >
            </v-card-title>
            <v-card-text class="pa-0" v-if="card.defenses && card.defenses.length > 0">
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
                  <tr v-for="d in card.defenses" :key="d.id">
                    <td>{{ d.position }}</td>
                    <td>{{ d.range_value }}</td>
                    <td>{{ d.error_rank }}</td>
                    <td>{{ d.throwing ?? '-' }}</td>
                  </tr>
                </tbody>
              </v-table>
            </v-card-text>
            <v-card-text v-else class="text-grey text-caption">守備値なし</v-card-text>
          </v-card>
        </v-col>

        <!-- 特徴 -->
        <v-col cols="12" sm="6">
          <v-card variant="outlined">
            <v-card-title class="text-subtitle-1 d-flex align-center">
              特徴・能力
              <v-spacer></v-spacer>
              <v-btn
                size="small"
                color="primary"
                variant="text"
                prepend-icon="mdi-pencil"
                @click="openTraitEditDialog"
                >編集</v-btn
              >
            </v-card-title>
            <v-card-text>
              <div v-if="card.trait_list && card.trait_list.length > 0" class="mb-2">
                <div class="text-caption text-grey mb-1">特徴</div>
                <div class="d-flex flex-wrap gap-1">
                  <v-chip
                    v-for="t in card.trait_list"
                    :key="t.id"
                    class="mr-1 mb-1"
                    size="small"
                    :title="traitTooltip(t)"
                  >
                    <template v-if="t.condition_name">
                      <span class="text-grey-darken-1">{{ t.condition_name }}/</span>
                    </template>
                    {{ t.name }}
                  </v-chip>
                </div>
              </div>
              <div v-if="card.ability_list && card.ability_list.length > 0">
                <div class="text-caption text-grey mb-1">能力</div>
                <div class="d-flex flex-wrap gap-1">
                  <v-chip
                    v-for="a in card.ability_list"
                    :key="a.id"
                    class="mr-1 mb-1"
                    size="small"
                    color="blue-grey"
                    variant="tonal"
                    :title="a.description ?? ''"
                  >
                    <template v-if="a.condition_name">
                      <span class="text-grey-darken-1">{{ a.condition_name }}/</span>
                    </template>
                    {{ a.name }}
                  </v-chip>
                </div>
              </div>
              <div
                v-if="
                  (!card.trait_list || card.trait_list.length === 0) &&
                  (!card.ability_list || card.ability_list.length === 0)
                "
                class="text-grey text-caption"
              >
                特徴・能力なし
              </div>
              <!-- 固有特徴 -->
              <template v-if="card.unique_traits">
                <v-divider class="my-2"></v-divider>
                <div class="text-caption text-grey mb-1">固有特徴</div>
                <pre class="text-body-2 text-wrap">{{ card.unique_traits }}</pre>
              </template>
              <!-- 怪我特徴 -->
              <template v-if="card.injury_traits">
                <v-divider class="my-2"></v-divider>
                <div class="text-caption text-grey mb-1">怪我特徴</div>
                <pre class="text-body-2 text-wrap">{{
                  JSON.stringify(card.injury_traits, null, 2)
                }}</pre>
              </template>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <!-- 投球P列 -->
      <v-row class="mt-0" v-if="card.pitching_table && card.pitching_table.length > 0">
        <v-col cols="12">
          <v-card variant="outlined">
            <v-card-title class="text-subtitle-1">投球P列</v-card-title>
            <v-card-text>
              <div class="d-flex flex-wrap gap-1">
                <v-chip
                  v-for="(p, idx) in card.pitching_table"
                  :key="idx"
                  size="x-small"
                  :color="pitchingCellColor(String(p))"
                  variant="tonal"
                  class="font-weight-bold"
                >
                  {{ idx + 1 }}: {{ p }}
                </v-chip>
              </div>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <!-- 打撃結果表 -->
      <v-row class="mt-0" v-if="card.batting_table && card.batting_table.length > 0">
        <v-col cols="12">
          <v-card variant="outlined">
            <v-card-title class="text-subtitle-1">打撃結果表</v-card-title>
            <v-card-text class="pa-0">
              <div class="overflow-x-auto">
                <v-table density="compact" class="batting-table">
                  <thead>
                    <tr>
                      <th class="text-center" style="width: 40px">出目</th>
                      <th v-for="col in battingTableColCount" :key="col" class="text-center">
                        P{{ col }}
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(row, rowIdx) in card.batting_table" :key="rowIdx">
                      <td class="text-center text-caption font-weight-bold">{{ rowIdx + 1 }}</td>
                      <td
                        v-for="(cell, colIdx) in row"
                        :key="colIdx"
                        class="text-center text-caption"
                        :class="battingResultClass(String(cell))"
                        :style="battingResultStyle(String(cell))"
                      >
                        {{ cell }}
                      </td>
                    </tr>
                  </tbody>
                </v-table>
              </div>
              <!-- 凡例 -->
              <div class="d-flex flex-wrap ga-2 pa-2 pt-1 text-caption text-grey-darken-1">
                <span class="d-flex align-center ga-1">
                  <span class="legend-swatch bg-orange-lighten-4"></span>安打・四死球
                </span>
                <span class="d-flex align-center ga-1">
                  <span class="legend-swatch bg-red-lighten-4"></span>アウト
                </span>
                <span class="d-flex align-center ga-1">
                  <span class="legend-swatch bg-blue-lighten-4"></span>進塁打
                </span>
                <span class="d-flex align-center ga-1">
                  <span class="legend-swatch bg-green-lighten-4"></span>レンジ
                </span>
                <span class="d-flex align-center ga-1">
                  <span class="legend-swatch bg-purple-lighten-4"></span>UP
                </span>
              </div>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
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

          <!-- 固有特徴（テキストエリア） -->
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
import { useTheme } from 'vuetify'
import { useRoute, useRouter } from 'vue-router'
import axios from '@/plugins/axios'

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

const vuetifyTheme = useTheme()
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

const battingTableColCount = computed(() => {
  if (!card.value?.batting_table?.length) return 0
  return card.value.batting_table[0].length
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

// ---- Trait tooltip helper ----
function traitTooltip(t: TraitItem): string {
  const parts = []
  if (t.condition_description) parts.push(`条件: ${t.condition_description}`)
  if (t.description) parts.push(t.description)
  return parts.join('\n')
}

// ---- Pitching table color ----
function pitchingCellColor(val: string): string {
  if (val.includes('*')) return 'orange'
  if (val.includes('P')) return 'red'
  return 'default'
}

// ---- Batting result color class (IRC準拠) ----
function getResultCategory(val: string): string | null {
  // 安打系: H#/H#a/2H#/2H#a/3H#/HR#/IH# + 四死球: BB/DB + 従来表記: 1B/2B/3B
  if (/^((HR|IH|[123]?H)\d{1,2}a?|BB|DB|[123]B)$/.test(val)) return 'orange'
  // レンジ系コード（外野: SS/RF/LF/CF/P, 内野守備力数値, レンジテキスト）
  if (/^(SS|RF|LF|CF|P|\d+|レンジ)$/.test(val)) return 'green'
  // aゴロ・aフライ（走者進塁アウト）
  if (/^[GF]\d{1,2}a$/.test(val)) return 'blue'
  // UP表参照
  if (val === 'UP') return 'purple'
  // その他のアウト: K, PO, G#/G#f/G#D, F#
  if (/^(K|PO|G\d{1,2}[fD]?|F\d{1,2})$/.test(val)) return 'red'
  return null
}

const categoryToClass = computed<Record<string, string>>(() => {
  if (vuetifyTheme.global.current.value.dark) {
    return {
      orange: 'bg-orange-darken-3',
      green: 'bg-green-darken-3',
      blue: 'bg-blue-darken-3',
      red: 'bg-red-darken-3',
      purple: 'bg-purple-darken-3',
    }
  }
  return {
    orange: 'bg-orange-lighten-4',
    green: 'bg-green-lighten-4',
    blue: 'bg-blue-lighten-4',
    red: 'bg-red-lighten-4',
    purple: 'bg-purple-lighten-4',
  }
})

const categoryToHex = computed<Record<string, string>>(() => {
  if (vuetifyTheme.global.current.value.dark) {
    return {
      orange: '#5D4037',
      green: '#1B5E20',
      blue: '#0D47A1',
      red: '#B71C1C',
      purple: '#4A148C',
    }
  }
  return {
    orange: '#FFE0B2',
    green: '#C8E6C9',
    blue: '#BBDEFB',
    red: '#FFCDD2',
    purple: '#E1BEE7',
  }
})

function battingResultClass(val: string): string {
  if (val.includes('/')) return ''
  const cat = getResultCategory(val)
  return cat ? categoryToClass.value[cat] : ''
}

function battingResultStyle(val: string): Record<string, string> {
  if (!val.includes('/')) return {}
  const parts = val.split('/')
  const cat1 = getResultCategory(parts[0])
  const cat2 = getResultCategory(parts[1])
  const hexMap = categoryToHex.value
  const c1 = cat1 ? hexMap[cat1] : 'transparent'
  const c2 = cat2 ? hexMap[cat2] : 'transparent'
  if (c1 === c2) return { background: c1 }
  return { background: `linear-gradient(135deg, ${c1} 50%, ${c2} 50%)` }
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
.batting-table :deep(table) {
  table-layout: fixed;
  width: 100%;
}
.batting-table td {
  padding: 2px 4px !important;
  font-size: 11px;
  white-space: nowrap;
}
.batting-table th {
  padding: 2px 4px !important;
  font-size: 11px;
}
.legend-swatch {
  display: inline-block;
  width: 12px;
  height: 12px;
  border-radius: 2px;
  border: 1px solid rgba(0, 0, 0, 0.15);
  flex-shrink: 0;
}
</style>
