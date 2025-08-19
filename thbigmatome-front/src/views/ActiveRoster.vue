<template>
  <v-container>
    <v-row>
      <v-col>
        <h1 class="text-h4">{{ t('activeRoster.title') }}</h1>
        <p>{{ t('activeRoster.currentDate') }}: {{ formattedCurrentDate }}</p>
        <p>{{ t('activeRoster.firstSquadCount') }}: {{ firstSquadPlayers.length }} / 29</p>
        <p>{{ t('activeRoster.firstSquadCost') }}: {{ firstSquadTotalCost }} / 120</p>
      </v-col>
    </v-row>

    <v-row class="mt-4">
      <v-col cols="12">
        <v-card>
          <v-card-title>{{ t('activeRoster.keyPlayerSelection') }}</v-card-title>
          <v-card-text>
            <v-select
              v-model="selectedKeyPlayerId"
              :items="availableKeyPlayers"
              item-title="player_name"
              item-value="team_membership_id"
              :label="t('activeRoster.selectKeyPlayer')"
              :disabled="!isSeasonStartDate"
              clearable
            ></v-select>
            <v-btn color="primary" @click="saveKeyPlayer" :disabled="!isSeasonStartDate">
              {{ t('activeRoster.saveKeyPlayer') }}
            </v-btn>
            <p v-if="!isSeasonStartDate" class="text-caption mt-2">
              {{ t('activeRoster.keyPlayerRestriction') }}
            </p>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-row class="mt-4">
      <v-col cols="6">
        <v-card>
          <v-card-title>{{ t('activeRoster.firstSquad') }}</v-card-title>
          <v-card-text>
            <v-data-table
              density="compact"
              :headers="firstHeaders"
              :items="firstSquadPlayers"
              hide-default-footer
              items-per-page="-1"
            >
              <template #item.actions="{ item }">
                  <v-btn icon size="small" @click="movePlayer(item, 'second')" :disabled="isPlayerOnCooldown(item)">
                    <v-icon>mdi-arrow-right</v-icon>
                  </v-btn>
              </template>
              <template #item.player_types="{ item }">
                <v-chip v-for="player_type in item.player_types" :key="player_type" density="compact" size="small">
                  {{ player_type }}
                </v-chip>
              </template>
              <template #item.position="{ item }">
                {{ t(`baseball.shortPositions.${item.position}`) }}
              </template>
              <template #item.throwing_hand="{ item }">
                {{ t(`baseball.throwingHands.${item.throwing_hand}`) }}
              </template>
              <template #item.batting_hand="{ item }">
                {{ t(`baseball.battingHands.${item.batting_hand}`) }}
              </template>
              <template #item.selected_cost_type="{ item }">
                {{ t(`baseball.construction.${item.selected_cost_type}`) }}
              </template>
            </v-data-table>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col cols="6">
        <v-card>
          <v-card-title>{{ t('activeRoster.secondSquad') }}</v-card-title>
          <v-card-text>
            <v-data-table
              density="compact"
              :headers="secondHeaders"
              :items="secondSquadPlayers"
              hide-default-footer
              items-per-page="-1"
            >
              <template #item.actions="{ item }">
                  <v-btn icon size="small" @click="movePlayer(item, 'first')" :disabled="isPlayerOnCooldown(item)">
                    <v-icon>mdi-arrow-left</v-icon>
                  </v-btn>
              </template>
              <template #item.player_types="{ item }">
                <v-chip v-for="player_type in item.player_types" :key="player_type" density="compact" size="small">
                  {{ player_type }}
                </v-chip>
              </template>
              <template #item.position="{ item }">
                {{ t(`baseball.shortPositions.${item.position}`) }}
              </template>
              <template #item.throwing_hand="{ item }">
                {{ t(`baseball.throwingHands.${item.throwing_hand}`) }}
              </template>
              <template #item.batting_hand="{ item }">
                {{ t(`baseball.battingHands.${item.batting_hand}`) }}
              </template>
              <template #item.selected_cost_type="{ item }">
                {{ t(`baseball.construction.${item.selected_cost_type}`) }}
              </template>
            </v-data-table>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-row class="mt-4">
      <v-col>
        <v-btn color="primary" @click="saveRoster">{{ t('activeRoster.saveRoster') }}</v-btn>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRoute } from 'vue-router';
import axios from 'axios';
import { useI18n } from 'vue-i18n';
import type { RosterPlayer } from '@/types/rosterPlayer';

const { t } = useI18n();
const route = useRoute();
const teamId = route.params.teamId;
const rosterPlayers = ref<RosterPlayer[]>([]);
const currentDate = ref(new Date());
const seasonStartDate = ref<Date | null>(null);
const selectedKeyPlayerId = ref<number | null>(null);

const headers = [
  { title: t('activeRoster.headers.number'), key: 'number' },
  { title: t('activeRoster.headers.name'), key: 'player_name' },
  { title: t('activeRoster.headers.player_types'), key: 'player_types' },
  { title: t('activeRoster.headers.position'), key: 'position' },
  { title: t('activeRoster.headers.throws'), key: 'throwing_hand' },
  { title: t('activeRoster.headers.bats'), key: 'batting_hand' },
  { title: t('activeRoster.headers.cost_type'), value: 'selected_cost_type' },
  { title: t('activeRoster.headers.cost'), key: 'cost' }
]
const firstHeaders = [
  ...headers,
  { title: t('activeRoster.headers.actions'), sortable: false, key: 'actions' },
]

const secondHeaders = [
  { title: t('activeRoster.headers.actions'), sortable: false, key: 'actions' },
  ...headers
]

const fetchRoster = async () => {
  try {
    const response = await axios.get(`/teams/${teamId}/roster`);
    rosterPlayers.value = response.data.roster;
    console.log('Fetched roster:', rosterPlayers.value)
    if (response.data.current_date) {
      currentDate.value = new Date(response.data.current_date);
    }
    if (response.data.season_start_date) {
      seasonStartDate.value = new Date(response.data.season_start_date);
    }
    if (response.data.key_player_id) {
      selectedKeyPlayerId.value = response.data.key_player_id;
    }
  } catch (error) {
    console.error('Failed to fetch roster:', error);
  }
};

const formattedCurrentDate = computed(() => {
  const date = currentDate.value;
  const month = date.getMonth() + 1;
  const day = date.getDate();
  return `${month}月${day}日`;
});

const firstSquadPlayers = computed(() => {
  return rosterPlayers.value.filter(p => p.squad === 'first');
});

const secondSquadPlayers = computed(() => {
  return rosterPlayers.value.filter(p => p.squad === 'second');
});

const firstSquadTotalCost = computed(() => {
  return firstSquadPlayers.value.reduce((sum, player) => sum + player.cost, 0);
});

const isSeasonStartDate = computed(() => {
  if (!seasonStartDate.value) return false;
  return currentDate.value.toDateString() === seasonStartDate.value.toDateString();
});

const availableKeyPlayers = computed(() => {
  return firstSquadPlayers.value; // All first squad players are potential key players
});

const movePlayer = (player: RosterPlayer, targetSquad: 'first' | 'second') => {
  const index = rosterPlayers.value.findIndex(p => p.team_membership_id === player.team_membership_id);
  if (index !== -1) {
    rosterPlayers.value[index].squad = targetSquad;
  }
};

const isPlayerOnCooldown = (player: RosterPlayer) => {
  if (player.cooldown_until) {
    const cooldownDate = new Date(player.cooldown_until);
    return currentDate.value < cooldownDate;
  }
  return false;
};

const saveRoster = async () => {
  try {
    const updates = rosterPlayers.value.map(player => ({
      team_membership_id: player.team_membership_id,
      squad: player.squad
    }));
    await axios.post(`/teams/${teamId}/roster`, {
      roster_updates: updates,
      target_date: currentDate.value.toISOString().split('T')[0]
    });
    alert(t('activeRoster.saveSuccess'));
    fetchRoster(); // Re-fetch to update cooldowns and status
  } catch (error: any) {
    console.error('Failed to save roster:', error);
    alert(`${t('activeRoster.saveFailed')}: ${error.response?.data?.error || error.message}`);
  }
};

const saveKeyPlayer = async () => {
  try {
    await axios.post(`/teams/${teamId}/key_player`, {
      key_player_id: selectedKeyPlayerId.value
    });
    alert(t('activeRoster.keyPlayerSaveSuccess'));
  } catch (error: any) {
    console.error('Failed to save key player:', error);
    alert(`${t('activeRoster.keyPlayerSaveFailed')}: ${error.response?.data?.error || error.message}`);
  }
};

onMounted(fetchRoster);
</script>