<template>
  <v-card variant="outlined" class="mt-2">
    <v-card-title class="d-flex align-center pa-4">
      {{ t('squadTextSettings.title') }}
    </v-card-title>

    <v-card-text>
      <v-row v-if="loading" class="justify-center my-4">
        <v-progress-circular indeterminate color="primary" />
      </v-row>

      <template v-else>
        <!-- ポジション表記 -->
        <div class="mb-4">
          <div class="text-subtitle-2 mb-2">{{ t('squadTextSettings.positionFormat') }}</div>
          <v-radio-group v-model="form.position_format" inline hide-details>
            <v-radio :label="t('squadTextSettings.positionFormatEnglish')" value="english" />
            <v-radio :label="t('squadTextSettings.positionFormatJapanese')" value="japanese" />
          </v-radio-group>
        </div>

        <!-- 投打表記 -->
        <div class="mb-4">
          <div class="text-subtitle-2 mb-2">{{ t('squadTextSettings.handednessFormat') }}</div>
          <v-radio-group v-model="form.handedness_format" inline hide-details>
            <v-radio :label="t('squadTextSettings.handednessFormatAlphabet')" value="alphabet" />
            <v-radio :label="t('squadTextSettings.handednessFormatKanji')" value="kanji" />
          </v-radio-group>
        </div>

        <!-- 登板履歴日付 -->
        <div class="mb-4">
          <div class="text-subtitle-2 mb-2">{{ t('squadTextSettings.dateFormat') }}</div>
          <v-radio-group v-model="form.date_format" inline hide-details>
            <v-radio :label="t('squadTextSettings.dateFormatAbsolute')" value="absolute" />
            <v-radio :label="t('squadTextSettings.dateFormatRelative')" value="relative" />
          </v-radio-group>
        </div>

        <!-- セクションヘッダー -->
        <div class="mb-4">
          <div class="text-subtitle-2 mb-2">{{ t('squadTextSettings.sectionHeaderFormat') }}</div>
          <v-radio-group v-model="form.section_header_format" inline hide-details>
            <v-radio :label="t('squadTextSettings.sectionHeaderFormatBracket')" value="bracket" />
            <v-radio :label="t('squadTextSettings.sectionHeaderFormatNone')" value="none" />
          </v-radio-group>
        </div>

        <!-- 背番号接頭辞 -->
        <div class="mb-4">
          <div class="text-subtitle-2 mb-2">{{ t('squadTextSettings.showNumberPrefix') }}</div>
          <v-switch
            v-model="form.show_number_prefix"
            :label="
              form.show_number_prefix ? t('squadTextSettings.show') : t('squadTextSettings.hide')
            "
            color="primary"
            hide-details
          />
        </div>

        <!-- 打者成績項目 -->
        <div class="mb-4">
          <div class="text-subtitle-2 mb-2">{{ t('squadTextSettings.battingStatsItems') }}</div>
          <v-row>
            <v-col v-for="key in battingStatsKeys" :key="key" cols="6" sm="4" class="py-1">
              <v-checkbox
                v-model="form.batting_stats_config[key]"
                :label="t(`squadTextSettings.battingStats.${key}`)"
                density="compact"
                hide-details
              />
            </v-col>
          </v-row>
        </div>

        <!-- 投手成績項目 -->
        <div class="mb-4">
          <div class="text-subtitle-2 mb-2">{{ t('squadTextSettings.pitchingStatsItems') }}</div>
          <v-row>
            <v-col v-for="key in pitchingStatsKeys" :key="key" cols="6" sm="4" class="py-1">
              <v-checkbox
                v-model="form.pitching_stats_config[key]"
                :label="t(`squadTextSettings.pitchingStats.${key}`)"
                density="compact"
                hide-details
              />
            </v-col>
          </v-row>
        </div>

        <!-- 保存ボタン -->
        <div class="d-flex justify-end mt-4">
          <v-btn color="accent" variant="flat" :loading="saving" @click="save">
            {{ t('squadTextSettings.save') }}
          </v-btn>
        </div>
      </template>
    </v-card-text>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color" timeout="3000">
      {{ snackbar.message }}
    </v-snackbar>
  </v-card>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  teamId: number
}>()

const { t } = useI18n()

interface SquadTextSettingData {
  id: number | null
  team_id: number
  position_format: string
  handedness_format: string
  date_format: string
  section_header_format: string
  show_number_prefix: boolean
  batting_stats_config: Record<string, boolean>
  pitching_stats_config: Record<string, boolean>
  updated_at: string | null
}

const battingStatsKeys = ['avg', 'hr', 'rbi', 'sb', 'obp', 'ops'] as const
const pitchingStatsKeys = ['w_l', 'games', 'era', 'so', 'ip', 'hold', 'save'] as const

const defaultBattingStats = (): Record<string, boolean> => ({
  avg: true,
  hr: true,
  rbi: true,
  sb: false,
  obp: false,
  ops: false,
})

const defaultPitchingStats = (): Record<string, boolean> => ({
  w_l: true,
  games: true,
  era: true,
  so: true,
  ip: true,
  hold: false,
  save: false,
})

const loading = ref(true)
const saving = ref(false)
const snackbar = ref({ show: false, message: '', color: 'success' })

const form = ref({
  position_format: 'english',
  handedness_format: 'alphabet',
  date_format: 'absolute',
  section_header_format: 'bracket',
  show_number_prefix: true,
  batting_stats_config: defaultBattingStats(),
  pitching_stats_config: defaultPitchingStats(),
})

function applyData(data: SquadTextSettingData) {
  form.value.position_format = data.position_format
  form.value.handedness_format = data.handedness_format
  form.value.date_format = data.date_format
  form.value.section_header_format = data.section_header_format
  form.value.show_number_prefix = data.show_number_prefix
  form.value.batting_stats_config = { ...defaultBattingStats(), ...data.batting_stats_config }
  form.value.pitching_stats_config = { ...defaultPitchingStats(), ...data.pitching_stats_config }
}

async function fetchSettings() {
  loading.value = true
  try {
    const res = await axios.get<SquadTextSettingData>(`/teams/${props.teamId}/squad_text_settings`)
    applyData(res.data)
  } catch {
    snackbar.value = { show: true, message: t('squadTextSettings.loadError'), color: 'error' }
  } finally {
    loading.value = false
  }
}

async function save() {
  saving.value = true
  try {
    const payload = {
      squad_text_setting: {
        position_format: form.value.position_format,
        handedness_format: form.value.handedness_format,
        date_format: form.value.date_format,
        section_header_format: form.value.section_header_format,
        show_number_prefix: form.value.show_number_prefix,
        batting_stats_config: form.value.batting_stats_config,
        pitching_stats_config: form.value.pitching_stats_config,
      },
    }
    const res = await axios.put<SquadTextSettingData>(
      `/teams/${props.teamId}/squad_text_settings`,
      payload,
    )
    applyData(res.data)
    snackbar.value = { show: true, message: t('squadTextSettings.saved'), color: 'success' }
  } catch {
    snackbar.value = { show: true, message: t('squadTextSettings.saveError'), color: 'error' }
  } finally {
    saving.value = false
  }
}

onMounted(() => {
  fetchSettings()
})
</script>
