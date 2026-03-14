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
      <v-list-item
        v-if="teamSelectionStore.selectedTeamId"
        prepend-icon="mdi-calendar-star"
        :title="'シーズン'"
        value="season"
        :to="`/teams/${teamSelectionStore.selectedTeamId}/season`"
        link
      />
    </v-list>

    <template v-if="showCommissionerMenu">
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
import { computed } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { useTeamSelectionStore } from '@/stores/teamSelection'
import { useCommissionerModeStore } from '@/stores/commissionerMode'

const props = defineProps<{
  modelValue: boolean
  rail: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  'update:rail': [value: boolean]
}>()

const { isCommissioner } = useAuth()
const teamSelectionStore = useTeamSelectionStore()
const commissionerModeStore = useCommissionerModeStore()

const showCommissionerMenu = computed(
  () => isCommissioner.value && commissionerModeStore.isCommissionerMode,
)

const mainMenuItems = [
  { title: 'ホーム', icon: 'mdi-home', value: 'dashboard', to: '/' },
  { title: '試合ログ', icon: 'mdi-file-import', value: 'gameImport', to: '/games/import' },
  { title: 'レビュー', icon: 'mdi-clipboard-check', value: 'gameRecords', to: '/game-records' },
  { title: '試合一覧', icon: 'mdi-scoreboard', value: 'games', to: '/games' },
  { title: '成績', icon: 'mdi-chart-bar', value: 'stats', to: '/stats' },
  {
    title: '選手カード',
    icon: 'mdi-card-account-details',
    value: 'playerCards',
    to: '/player-cards',
  },
]

const commissionerMenuItems = [
  {
    title: 'ダッシュボード',
    icon: 'mdi-view-dashboard',
    value: 'commissionerDashboard',
    to: '/commissioner/dashboard',
  },
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
    title: '監督一覧',
    icon: 'mdi-account-tie',
    value: 'managers',
    to: '/managers',
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
