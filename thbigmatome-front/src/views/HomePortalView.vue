<template>
  <v-container>
    <!-- ローディング中 -->
    <v-progress-circular
      v-if="loading"
      indeterminate
      color="primary"
      class="d-block mx-auto my-8"
    />

    <!-- コミッショナー: タブUI -->
    <template v-else-if="isCommissioner">
      <!-- リリース向けUI整理: 自チーム・全チーム管理タブは非表示、ダッシュボードのみ表示 -->
      <!--
      <v-tabs v-model="activeTab" color="primary" class="mb-4">
        <v-tab value="myTeams">自チーム</v-tab>
        <v-tab value="allTeams">全チーム管理</v-tab>
        <v-tab value="dashboard">ダッシュボード</v-tab>
      </v-tabs>
      -->

      <!-- <v-window v-model="activeTab"> -->
      <!-- 自チームタブ -->
      <!--
        <v-window-item value="myTeams">
          <v-empty-state
            v-if="myTeams.length === 0"
            icon="mdi-account-group-outline"
            title="チームが割り当てられていません"
            text="チーム未割り当て。コミッショナーにお問い合わせください。"
            class="mt-8"
          />
          <SeasonPortal
            v-else-if="myTeams.length === 1"
            :key="myTeams[0].id"
            :team-id="myTeams[0].id"
          />
          <template v-else>
            <v-tabs v-model="selectedTeamId" color="primary" class="mb-2">
              <v-tab v-for="team in myTeams" :key="team.id" :value="team.id">
                {{ team.name }}
              </v-tab>
            </v-tabs>
            <SeasonPortal :key="selectedTeamId" :team-id="selectedTeamId" />
          </template>
        </v-window-item>
        -->

      <!-- 全チーム管理タブ -->
      <!--
        <v-window-item value="allTeams">
          <v-select
            v-model="selectedAllTeamId"
            :items="allTeams"
            item-title="name"
            item-value="id"
            label="チームを選択"
            class="mb-2"
          />
          <SeasonPortal
            v-if="selectedAllTeamId"
            :key="selectedAllTeamId"
            :team-id="selectedAllTeamId"
          />
        </v-window-item>
        -->

      <!-- ダッシュボード -->
      <CommissionerDashboard />
      <!-- </v-window> -->
    </template>

    <!-- 非コミッショナー: 既存表示 -->
    <template v-else>
      <!-- チーム0件 -->
      <v-empty-state
        v-if="myTeams.length === 0"
        icon="mdi-account-group-outline"
        title="チームが割り当てられていません"
        text="チーム未割り当て。コミッショナーにお問い合わせください。"
        class="mt-8"
      />

      <!-- チーム1件: 即SeasonPortal表示 -->
      <SeasonPortal
        v-else-if="myTeams.length === 1"
        :key="myTeams[0].id"
        :team-id="myTeams[0].id"
      />

      <!-- チーム2件以上: タブ切り替え -->
      <template v-else>
        <v-tabs v-model="selectedTeamId" color="primary" class="mb-2">
          <v-tab v-for="team in myTeams" :key="team.id" :value="team.id">
            {{ team.name }}
          </v-tab>
        </v-tabs>
        <SeasonPortal :key="selectedTeamId" :team-id="selectedTeamId" />
      </template>
    </template>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useTeamSelectionStore } from '@/stores/teamSelection'
import { useAuth } from '@/composables/useAuth'
import { type Team } from '@/types/team'
import SeasonPortal from '@/views/SeasonPortal.vue'
import CommissionerDashboard from '@/components/commissioner/CommissionerDashboard.vue'

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
  myTeams.value = teamSelectionStore.myTeams as Team[]
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
