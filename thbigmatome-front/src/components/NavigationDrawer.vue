<template>
  <v-navigation-drawer
    :model-value="modelValue"
    :rail="rail"
    :rail-width="72"
    @update:model-value="emit('update:modelValue', $event)"
    @click="expandDrawer"
  >
    <v-list nav density="compact">
      <v-list-item
        v-for="item in menuItems"
        :key="item.value"
        :prepend-icon="item.icon"
        :title="item.title"
        :value="item.value"
        :to="item.to"
        link
      />
    </v-list>

    <v-divider class="my-1" />

    <v-list nav density="compact">
      <v-list-subheader v-if="!rail">外部リンク</v-list-subheader>
      <v-list-item
        href="https://thbigbaseball.wiki.fc2.com/"
        target="_blank"
        prepend-icon="mdi-baseball-diamond"
        title="公式Wiki"
        value="officialWiki"
        link
      >
        <template v-slot:append v-if="!rail">
          <v-icon size="x-small">mdi-open-in-new</v-icon>
        </template>
      </v-list-item>
    </v-list>

    <template v-slot:append>
      <v-list-item
        @click.stop="emit('update:rail', !rail)"
        :prepend-icon="rail ? 'mdi-chevron-right' : 'mdi-chevron-left'"
        :title="rail ? 'メニューを展開' : 'メニューを縮小'"
      />
    </template>
  </v-navigation-drawer>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useAuth } from '@/composables/useAuth'

const props = defineProps<{
  modelValue: boolean
  rail: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  'update:rail': [value: boolean]
}>()

const { isCommissioner } = useAuth()

const menuItems = computed(() => {
  const items = [
    { title: 'ホーム', icon: 'mdi-view-dashboard', value: 'dashboard', to: '/menu' },
    { title: 'チーム編成', icon: 'mdi-account-group', value: 'teams', to: '/teams' },
    { title: '選手マスタ', icon: 'mdi-account', value: 'players', to: '/players' },
    {
      title: 'コスト管理',
      icon: 'mdi-currency-jpy',
      value: 'costAssignment',
      to: '/cost_assignment',
    },
    { title: '試合記録', icon: 'mdi-scoreboard', value: 'games', to: '/games' },
    { title: 'ログ取り込み', icon: 'mdi-file-import', value: 'gameImport', to: '/games/import' },
    { title: '設定', icon: 'mdi-cog', value: 'settings', to: '/settings' },
  ]

  if (isCommissioner.value) {
    items.push({
      title: 'リーグ管理',
      icon: 'mdi-trophy',
      value: 'leagues',
      to: '/commissioner/leagues',
    })
    items.push({
      title: '球場管理',
      icon: 'mdi-stadium',
      value: 'stadiums',
      to: '/commissioner/stadiums',
    })
    items.push({
      title: 'カードセット',
      icon: 'mdi-cards',
      value: 'cardSets',
      to: '/commissioner/card_sets',
    })
    items.push({
      title: '大会管理',
      icon: 'mdi-trophy-outline',
      value: 'competitions',
      to: '/commissioner/competitions',
    })
  }

  return items
})

const expandDrawer = () => {
  if (props.rail) emit('update:rail', false)
}
</script>
