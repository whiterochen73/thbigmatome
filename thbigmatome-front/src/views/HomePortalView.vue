<template>
  <v-container>
    <!-- ローディング中 -->
    <v-progress-circular
      v-if="loading"
      indeterminate
      color="primary"
      class="d-block mx-auto my-8"
    />

    <!-- チーム0件 -->
    <v-empty-state
      v-else-if="myTeams.length === 0"
      icon="mdi-account-group-outline"
      title="チームが割り当てられていません"
      text="チーム未割り当て。コミッショナーにお問い合わせください。"
      class="mt-8"
    />

    <!-- チーム1件: 即SeasonPortal表示 -->
    <SeasonPortal v-else-if="myTeams.length === 1" :key="myTeams[0].id" :team-id="myTeams[0].id" />

    <!-- チーム2件以上: タブ切り替え -->
    <template v-else>
      <v-tabs v-model="selectedTeamId" color="primary" class="mb-2">
        <v-tab v-for="team in myTeams" :key="team.id" :value="team.id">
          {{ team.name }}
        </v-tab>
      </v-tabs>
      <SeasonPortal :key="selectedTeamId" :team-id="selectedTeamId" />
    </template>
  </v-container>
</template>

<script setup lang="ts">
import { ref, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from '@/plugins/axios'
import { useCommissionerModeStore } from '@/stores/commissionerMode'
import { useTeamSelectionStore } from '@/stores/teamSelection'
import { type Team } from '@/types/team'
import SeasonPortal from '@/views/SeasonPortal.vue'

const router = useRouter()
const commissionerModeStore = useCommissionerModeStore()
const teamSelectionStore = useTeamSelectionStore()

const myTeams = ref<Team[]>([])
// Approach C: teamsLoaded済みならキャッシュを使い、即座にloading=falseで開始する（再マウント時のレースコンディション対策）
const loading = ref(!teamSelectionStore.teamsLoaded)
const selectedTeamId = ref<number>(0)

// AppBarのwatchEffectがteamsLoaded後にcommissionerModeをtrueにする場合のリダイレクト対応
// （チーム未所持コミッショナーの初回ログイン時タイミング問題）
watch(
  () => commissionerModeStore.isCommissionerMode,
  (val) => {
    if (val) {
      loading.value = false
      router.push('/commissioner/dashboard')
    }
  },
)

onMounted(async () => {
  // Fix: コミッショナーモードリダイレクト時はloading=falseを必ず設定してから戻る
  if (commissionerModeStore.isCommissionerMode) {
    loading.value = false
    router.push('/commissioner/dashboard')
    return
  }

  // キャッシュ済みデータがある場合は再フェッチをスキップ
  if (teamSelectionStore.teamsLoaded) {
    myTeams.value = teamSelectionStore.myTeams as Team[]
    if (myTeams.value.length > 0) {
      const storedId = teamSelectionStore.selectedTeamId
      const found = myTeams.value.find((t) => t.id === storedId)
      selectedTeamId.value = found ? found.id : myTeams.value[0].id
    }
    return
  }

  try {
    const response = await axios.get<Team[]>('/users/me/teams')
    myTeams.value = response.data
    // Storeにキャッシュ（teamsLoaded=trueにする）→ NavigationDrawer/AppBarが正しく制御できる
    teamSelectionStore.setMyTeams(response.data)
    if (myTeams.value.length > 0) {
      const storedId = teamSelectionStore.selectedTeamId
      const found = myTeams.value.find((t) => t.id === storedId)
      selectedTeamId.value = found ? found.id : myTeams.value[0].id
    }
  } finally {
    loading.value = false
  }
})

watch(selectedTeamId, (id) => {
  const team = myTeams.value.find((t) => t.id === id)
  if (team) teamSelectionStore.selectTeam(team.id, team.name)
})
</script>
