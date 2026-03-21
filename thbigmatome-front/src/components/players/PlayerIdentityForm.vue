<template>
  <div>
    <v-row density="compact">
      <v-col cols="12" sm="3">
        <v-text-field
          v-model="editableItem.number"
          :label="t('playerDialog.form.number')"
          maxlength="4"
          density="compact"
          clearable
          autofocus
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="5">
        <v-text-field
          v-model="editableItem.name"
          :label="t('playerDialog.form.name')"
          :rules="[rules.required]"
          required
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="4">
        <v-text-field
          v-model="editableItem.short_name"
          :label="t('playerDialog.form.short_name')"
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="4">
        <v-select
          v-model="editableItem.series"
          :label="t('playerDialog.form.series')"
          :items="seriesItems"
          item-title="label"
          item-value="value"
          density="compact"
          clearable
        ></v-select>
      </v-col>
    </v-row>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import type { PlayerDetail } from '@/types/playerDetail'

const { t } = useI18n()

const editableItem = defineModel<PlayerDetail>({
  type: Object,
  required: true,
})

const seriesItems = [
  { value: 'touhou', label: '東方Project' },
  { value: 'hachinai', label: 'ハチナイ' },
  { value: 'tamayomi', label: '球詠' },
  { value: 'original', label: 'オリジナル' },
]

const rules = {
  required: (value: string | number) =>
    (value !== null && value !== '') || t('validation.required'),
}
</script>
