<template>
  <!-- ローディング中 -->
  <PageLayout v-if="loading">
    <AsyncState loading empty skeleton="article" />
  </PageLayout>

  <!-- コミッショナー: ダッシュボードのみ表示（リリース向けUI整理: 自チーム・全チーム管理タブは非表示。ポストリリースで復活予定） -->
  <PageLayout v-else-if="isCommissioner">
    <CommissionerDashboard />
  </PageLayout>

  <!-- 非コミッショナー: 既存表示 -->
  <!-- チーム0件 -->
  <PageLayout v-else-if="myTeams.length === 0">
    <AsyncState
      empty
      empty-icon="mdi-account-group-outline"
      empty-message="チームが割り当てられていません。コミッショナーにお問い合わせください。"
    />
  </PageLayout>

  <!-- チーム1件: 即SeasonPortal表示（バーのタイトルはシーズンが宣言する） -->
  <SeasonPortal v-else-if="myTeams.length === 1" :key="myTeams[0].id" :team-id="myTeams[0].id" />

  <!-- チーム2件以上: タブ切り替え -->
  <template v-else>
    <PageLayout width="wide" class="home-team-tabs">
      <template #tabs>
        <v-tabs v-model="selectedTeamId" color="link">
          <v-tab v-for="team in myTeams" :key="team.id" :value="team.id">
            {{ team.name }}
          </v-tab>
        </v-tabs>
      </template>
    </PageLayout>
    <SeasonPortal :key="selectedTeamId" :team-id="selectedTeamId" />
  </template>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useTeamSelectionStore } from '@/stores/teamSelection'
import { useAuth } from '@/composables/useAuth'
import { type Team } from '@/types/team'
import SeasonPortal from '@/views/SeasonPortal.vue'
import CommissionerDashboard from '@/components/commissioner/CommissionerDashboard.vue'
import AsyncState from '@/components/shared/AsyncState.vue'
import PageLayout from '@/components/shared/PageLayout.vue'

const teamSelectionStore = useTeamSelectionStore()
const { isCommissioner } = useAuth()

const myTeams = ref<Team[]>([])
// teamsLoadedはuseAuth(login/checkAuth)で保証済み → loading初期値はfalse固定
const loading = ref(false)
const selectedTeamId = ref<number>(0)

// リリース非表示: タブ関連変数（ポストリリースで復活予定）
// const allTeams = computed(() => teamSelectionStore.allTeams)
// const activeTab = ref('myTeams')
// const selectedAllTeamId = ref<number | null>(null)

onMounted(() => {
  myTeams.value = teamSelectionStore.myTeams as unknown as Team[]
  if (myTeams.value.length > 0) {
    const storedId = teamSelectionStore.selectedTeamId
    const found = myTeams.value.find((t) => t.id === storedId)
    selectedTeamId.value = found ? found.id : myTeams.value[0].id
  }
  // コミッショナーかつチーム未所持の場合、初期タブを全チーム管理に（リリース非表示中は不要）
  // if (isCommissioner.value && myTeams.value.length === 0) {
  //   activeTab.value = 'allTeams'
  // }
})

watch(selectedTeamId, (id) => {
  const team = myTeams.value.find((t) => t.id === id)
  if (team) teamSelectionStore.selectTeam(team.id, team.name)
})
</script>

<style scoped>
/* チーム切り替えのタブだけの帯。下の SeasonPortal が自分の上余白を持つので、ここは下余白を詰める */
.home-team-tabs {
  padding-bottom: 0;
}
</style>
