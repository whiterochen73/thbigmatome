<template>
  <div class="row-menu">
    <v-menu location="bottom end">
      <template #activator="{ props: activatorProps }">
        <v-btn
          v-bind="activatorProps"
          icon="mdi-dots-vertical"
          variant="text"
          size="small"
          class="on-surface-variant row-menu__activator"
          :aria-label="label"
          :title="label"
          data-testid="row-menu"
        />
      </template>
      <v-list density="compact">
        <v-list-item
          v-for="item in items"
          :key="item.label"
          :prepend-icon="item.icon"
          :title="item.label"
          :base-color="item.danger ? 'danger-ink' : undefined"
          @click="item.onClick()"
        />
      </v-list>
    </v-menu>
  </div>
</template>

<script setup lang="ts">
// 表の行の操作が 3 つ以上ある時、スマホ（<600px）の縦積み行で使う操作メニュー（2 つまではアイコンボタンのまま）。
// PC では同じ操作を RowIconButton で並べ（class="row-actions row-actions--full"。600px 未満では PageLayout の CSS が隠す）、本部品は 600px 以上で隠す
export interface RowMenuItem {
  icon: string
  label: string
  danger?: boolean
  onClick: () => void
}

defineProps<{
  label: string
  items: RowMenuItem[]
}>()
</script>

<style scoped>
@media (min-width: 600px) {
  .row-menu {
    display: none;
  }
}
</style>
