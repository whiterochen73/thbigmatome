<template>
  <v-btn
    :icon="icon"
    variant="text"
    size="small"
    :color="danger ? 'danger-ink' : 'link'"
    :aria-label="label"
    :title="label"
  />
</template>

<script setup lang="ts">
// 表の行の操作。名前を持つアイコンボタン（編集=link、削除=danger-ink。塗らない）
defineProps<{
  icon: string
  label: string
  danger?: boolean
}>()
</script>
