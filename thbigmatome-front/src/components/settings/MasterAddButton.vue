<template>
  <v-btn
    v-if="xs"
    icon="mdi-plus"
    color="link"
    variant="outlined"
    :style="{ borderColor: 'rgb(var(--v-theme-border-strong))' }"
    :aria-label="label"
    :title="label"
    data-testid="master-add"
  />
  <v-btn
    v-else
    color="link"
    variant="outlined"
    size="small"
    prepend-icon="mdi-plus"
    :style="{ borderColor: 'rgb(var(--v-theme-border-strong))' }"
    :aria-label="label"
    data-testid="master-add"
  >
    {{ text ?? label }}
  </v-btn>
</template>

<script setup lang="ts">
import { useDisplay } from 'vuetify'

// 副操作（R5）: 枠＋プラス。同格の「追加」が並ぶ画面に塗りの緑を並べない。
// スマホ幅（xs）では + のアイコンだけにして、パネル名を省略させない（名前は aria-label と title が持つ）
// （コメントはテンプレートに置かない。ルートが複数になり、class・listener が v-btn に届かなくなる）
defineProps<{
  /** aria-label（例: 「特徴を追加」）。表示文字と同じなら text は省く */
  label: string
  text?: string
}>()

const { xs } = useDisplay()
</script>
