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
        v-for="item in mainMenuItems"
        :key="item.value"
        :prepend-icon="item.icon"
        :title="item.title"
        :value="item.value"
        :to="item.to"
        link
      />
    </v-list>

    <template v-if="isCommissioner">
      <v-divider class="my-1" />
      <v-list nav density="compact">
        <v-list-subheader v-if="!rail">管理</v-list-subheader>
        <v-list-item
          v-for="item in commissionerMenuItems"
          :key="item.value"
          :prepend-icon="item.icon"
          :title="item.title"
          :value="item.value"
          :to="item.to"
          link
        />
      </v-list>
    </template>

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

const mainMenuItems = [
  { title: 'ホーム', icon: 'mdi-home', value: 'dashboard', to: '/' },
  { title: '試合記録', icon: 'mdi-scoreboard', value: 'games', to: '/games' },
  { title: '成績まとめ', icon: 'mdi-chart-bar', value: 'stats', to: '/stats' },
  { title: 'チーム編成', icon: 'mdi-account-group', value: 'teams', to: '/teams' },
]

const commissionerMenuItems = [
  {
    title: '大会管理',
    icon: 'mdi-trophy-outline',
    value: 'competitions',
    to: '/commissioner/competitions',
  },
  {
    title: 'カードセット',
    icon: 'mdi-cards',
    value: 'cardSets',
    to: '/commissioner/card_sets',
  },
  { title: '球場', icon: 'mdi-stadium', value: 'stadiums', to: '/commissioner/stadiums' },
  {
    title: '選手マスタ',
    icon: 'mdi-account',
    value: 'commissionerPlayers',
    to: '/commissioner/players',
  },
  {
    title: 'ユーザー管理',
    icon: 'mdi-account-cog',
    value: 'users',
    to: '/commissioner/users',
  },
]

const expandDrawer = () => {
  if (props.rail) emit('update:rail', false)
}
</script>
