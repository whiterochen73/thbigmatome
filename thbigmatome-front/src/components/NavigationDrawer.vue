<template>
  <v-navigation-drawer
    :model-value="modelValue"
    :rail="rail"
    :rail-width="72"
    @update:model-value="emit('update:modelValue', $event)"
    @click="expandDrawer"
  >
    <v-list nav density="compact">
      <!-- ホーム（単独） -->
      <v-list-item prepend-icon="mdi-home" title="ホーム" value="dashboard" to="/" link />

      <!-- 試合グループ -->
      <v-list-subheader v-if="!rail">試合</v-list-subheader>
      <v-list-item
        v-for="item in gameMenuItems"
        :key="item.value"
        :prepend-icon="item.icon"
        :title="item.title"
        :value="item.value"
        :to="item.to"
        link
      />

      <!-- チームグループ（コミッショナーモード時は常に表示、通常時はチーム所持時のみ） -->
      <template v-if="showTeamMenu">
        <v-list-subheader v-if="!rail">チーム</v-list-subheader>
        <v-list-item
          v-if="teamSelectionStore.selectedTeamId"
          prepend-icon="mdi-calendar-star"
          :title="'シーズン'"
          value="season"
          :to="`/teams/${teamSelectionStore.selectedTeamId}/season`"
          link
        />
        <v-list-item
          v-for="item in teamMenuItems"
          :key="item.value"
          :prepend-icon="item.icon"
          :title="item.title"
          :value="item.value"
          :to="item.to"
          link
        />
      </template>

      <!-- 選手グループ -->
      <v-list-subheader v-if="!rail">選手</v-list-subheader>
      <v-list-item
        v-for="item in playerMenuItems"
        :key="item.value"
        :prepend-icon="item.icon"
        :title="item.title"
        :value="item.value"
        :to="item.to"
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

const showCommissionerMenu = computed(() => isCommissioner.value)

const showTeamMenu = computed(() => {
  if (isCommissioner.value) return true
  return !teamSelectionStore.teamsLoaded || teamSelectionStore.hasTeam
})

const gameMenuItems = [
  { title: 'ログ取り込み (β)', icon: 'mdi-file-import', value: 'gameImport', to: '/games/import' },
  // { title: 'レビュー', icon: 'mdi-clipboard-check', value: 'gameRecords', to: '/game-records' }, // リリース非表示
  // { title: '試合一覧', icon: 'mdi-scoreboard', value: 'games', to: '/games' }, // リリース非表示
]

const teamMenuItems: { title: string; icon: string; value: string; to: string }[] = [
  // { title: '成績', icon: 'mdi-chart-bar', value: 'stats', to: '/stats' }, // リリース非表示
]

const playerMenuItems = [
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
    title: 'チーム一覧',
    icon: 'mdi-shield-account',
    value: 'teams',
    to: '/teams',
  },
  // { title: '大会管理', icon: 'mdi-trophy-outline', value: 'competitions', to: '/commissioner/competitions' }, // メニュー非表示
  {
    title: 'カードセット',
    icon: 'mdi-cards',
    value: 'cardSets',
    to: '/commissioner/card_sets',
  },
  // { title: '球場', icon: 'mdi-stadium', value: 'stadiums', to: '/commissioner/stadiums' }, // メニュー非表示
  {
    title: '選手一覧',
    icon: 'mdi-account',
    value: 'commissionerPlayers',
    to: '/commissioner/players',
  },
  {
    title: 'コスト登録',
    icon: 'mdi-currency-jpy',
    value: 'costAssignment',
    to: '/cost_assignment',
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
