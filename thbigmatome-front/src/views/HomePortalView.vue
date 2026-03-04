<template>
  <v-container v-if="!redirecting">
    <v-card max-width="480" class="mx-auto mt-8" elevation="2">
      <v-card-title class="text-h6">チームを選択してください</v-card-title>
      <v-card-text>
        <v-progress-circular
          v-if="loading"
          indeterminate
          color="primary"
          class="d-block mx-auto my-4"
        />
        <v-select
          v-else
          v-model="selectedTeamId"
          :items="teams"
          item-title="name"
          item-value="id"
          label="チーム"
          density="compact"
          @update:model-value="onTeamSelect"
        />
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from '@/plugins/axios'
import { useTeamSelectionStore } from '@/stores/teamSelection'
import { type Team } from '@/types/team'

const router = useRouter()
const teamSelectionStore = useTeamSelectionStore()

const teams = ref<Team[]>([])
const selectedTeamId = ref<number | null>(null)
const loading = ref(true)
const redirecting = ref(false)

onMounted(async () => {
  if (teamSelectionStore.selectedTeamId) {
    redirecting.value = true
    router.push(`/teams/${teamSelectionStore.selectedTeamId}/season`)
    return
  }
  try {
    const response = await axios.get<Team[]>('/teams')
    teams.value = response.data
  } finally {
    loading.value = false
  }
})

function onTeamSelect(teamId: number) {
  const team = teams.value.find((t) => t.id === teamId)
  if (team) {
    teamSelectionStore.selectTeam(team.id, team.name)
    router.push(`/teams/${team.id}/season`)
  }
}
</script>
