<template>
  <v-btn
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
// 副操作（R5）: 枠＋プラス。同格の「追加」が並ぶ画面に塗りの緑を並べない
// （コメントはテンプレートに置かない。ルートが複数になり、class・listener が v-btn に届かなくなる）
defineProps<{
  /** aria-label（例: 「特徴を追加」）。表示文字と同じなら text は省く */
  label: string
  text?: string
}>()
</script>
