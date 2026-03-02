<template>
  <div class="batting-table-wrapper">
    <v-table density="compact" class="batting-table">
      <thead>
        <tr>
          <th class="text-center" style="width: 40px">出目</th>
          <th v-for="col in colCount" :key="col" class="text-center">P{{ col }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(row, rowIdx) in table" :key="rowIdx">
          <td class="text-center text-caption font-weight-bold">{{ rowIdx + 2 }}</td>
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
      <span class="d-flex align-center ga-1">
        <span
          class="legend-swatch"
          style="background: linear-gradient(135deg, #ffe0b2 50%, #ffcdd2 50%)"
        ></span
        >スラッシュ（2色）
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useTheme } from 'vuetify'

interface Props {
  table: string[][]
}

const props = defineProps<Props>()
const vuetifyTheme = useTheme()

const colCount = computed(() => {
  if (!props.table?.length) return 0
  return props.table[0].length
})

// ---- Batting result color logic (IRC準拠) ----
function getResultCategory(val: string): string | null {
  // レンジ系コード（先に判定: 1B/2B/3B はポジション番号=一/二/三塁手のレンジ結果）
  if (/^(SS|RF|LF|CF|P|\d+|[123]B|レンジ)$/.test(val)) return 'green'
  // 安打系: H#/H#a/2H#/2H#a/3H#/HR#/IH# + 四死球: BB/DB
  if (/^((HR|IH|[123]?H)\d{1,2}a?|BB|DB)$/.test(val)) return 'orange'
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
      orange: '#E65100',
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
</script>

<style scoped>
.batting-table-wrapper {
  width: 100%;
}

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
