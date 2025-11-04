<template>
  <v-container>
    <v-toolbar color="green">
      <template #prepend>
        <span class="text-h5 mx-4">{{ gameData.team_name }}</span>
        <span class="text-h6 mx-4">{{ t('gameResult.game') }}: {{ gameData.game_number }}</span>
        <span class="text-h6 mx-4">{{ formattedGameDate }}</span>
        <span class="text-h6 mx-4">vs. {{ gameData.opponent_team_name }}</span>
        <span class="text-h6 mx-4" v-if="gameData.score !== null && gameData.opponent_score !== null">
          {{ gameData.score }} - {{ gameData.opponent_score }}
          <span class="ml-2">( {{ gameResult }} )</span>
        </span>
      </template>
      <v-btn
        :to="gameResultRoute"
        color="light"
        variant="flat"
      >
        試合結果に戻る
      </v-btn>
      <template #append>
        <v-btn
          @click="isStartingMemberDialogOpen = true"
          color="secondary"
          variant="flat"
          class="mr-4"
        >
          スタメン登録
        </v-btn>
      </template>
    </v-toolbar>
    <v-table v-if="gameData.scoreboard" density="compact" class="scoreboard-table">
      <thead>
        <tr>
          <th class="team-name-header">{{ t('gameResult.team') }}</th>
          <th v-for="(_, index) in gameData.scoreboard.away" :key="index" class="inning-header">{{ index + 1 }}</th>
          <th class="total-header">{{ t('gameResult.total') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td class="team-name">{{ awayTeamName }}</td>
          <td v-for="(score, index) in gameData.scoreboard.away" :key="index" class="inning-score">
            {{ score }}
          </td>
          <td class="total-score">{{ awayTeamScore }}</td>
        </tr>
        <tr>
          <td class="team-name">{{ homeTeamName }}</td>
          <td v-for="(_, index) in gameData.scoreboard.away" :key="index" class="inning-score">
            {{ gameData.scoreboard.home[index] ?? 'X' }}
          </td>
          <td class="total-score">{{ homeTeamScore }}</td>
        </tr>
      </tbody>
    </v-table>
    <v-snackbar
      v-model="snackbar"
      :color="snackbarColor"
      :timeout="3000"
    >
      {{ snackbarText }}
    </v-snackbar>
    <StartingMemberDialog
      v-model="isStartingMemberDialogOpen"
      :home-team-id="gameData.team_id"
      :all-players="allPlayers"
      :designated-hitter-enabled="gameData.designated_hitter_enabled"
      :initial-home-lineup="initialHomeLineupForDialog"
      :initial-opponent-lineup="initialOpponentLineupForDialog"
      @save="handleSaveStartingMembers"
    />
    <v-table v-if="startingMembers.length > 0" class="batting-record-table mt-6">
      <thead>
        <tr>
          <th>{{ t('scoreSheet.order') }}</th>
          <th>{{ t('scoreSheet.player') }}</th>
          <th>{{ t('scoreSheet.position') }}</th>
          <th v-for="i in 9" :key="i">{{ i }}</th>
          <th>{{ t('scoreSheet.hits') }}</th>
          <th>{{ t('scoreSheet.rbi') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(player, index) in startingMembers" :key="player.id">
          <td>{{ getPosition(player.id) }}</td>
          <td>{{ player.name }}</td>
          <td>{{ getPositionName(player.id) }}</td>
          <td v-for="i in 9" :key="i">
            <v-select
              v-model="battingResults[player.id][i]"
              :items="atBatOptions"
              density="compact"
              hide-details
              variant="underlined"
              class="inning-result-select"
            ></v-select>
          </td>
          <td>{{- '' }}</td>
          <td>{{- '' }}</td>
        </tr>
      </tbody>
    </v-table>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue';
import { useRoute } from 'vue-router';
import axios from 'axios';
import { useI18n } from 'vue-i18n';
import type { GameData } from '@/types/gameData';
import type { Player } from '@/types/player';
import type { Team } from '@/types/team';
import type { StartingMember } from '@/types/startingMember';
import StartingMemberDialog from '@/components/StartingMemberDialog.vue';

const { t } = useI18n();
const route = useRoute();

const snackbar = ref(false);
const snackbarText = ref('');
const snackbarColor = ref('success');
const isStartingMemberDialogOpen = ref(false);

const teamId = route.params.teamId;
const scheduleId = route.params.scheduleId;

const defaultGameData: GameData = {
  team_id: 0, team_name: '', season_id: 0, game_date: '', game_number: 0,
  announced_starter_id: null, stadium: '', home_away: null, designated_hitter_enabled: null,
  opponent_team_id: null, opponent_team_name: '',
  score: null, opponent_score: null,
  winning_pitcher_id: null, losing_pitcher_id: null, save_pitcher_id: null,
  scoreboard: {
    home: Array(9).fill(null),
    away: Array(9).fill(null),
  },
  starting_lineup: [],
  opponent_starting_lineup: [],
}

const gameData = ref<GameData>(defaultGameData);
const allTeams = ref<Team[]>([]);
const players = ref<Player[]>([]);
const allPlayers = ref<Player[]>([]);
const startingMembers = ref<Player[]>([]);
const startingPositions = ref<Record<number, { position: string, order: number }>>({});
const opponentStartingMembers = ref<Player[]>([]);
const opponentStartingPositions = ref<Record<number, { position: string, order: number }>>({});
const battingResults = ref<Record<number, Record<number, string | null>>>({});

const atBatOptions = ref([
  '安打', '二塁打', '三塁打', '本塁打', '犠打', '犠飛', '四球', '死球', '三振', '併殺', 'ゴロ', 'フライ'
]);

const gameResultRoute = computed(() => {
  return {
    name: 'GameResult',
    params: {
      teamId: teamId,
      scheduleId: scheduleId
    }
  };
});

const initialHomeLineupForDialog = computed(() => {
  if (startingMembers.value.length === 0) {
    return [];
  }
  return startingMembers.value.map(player => {
    const positionInfo = startingPositions.value[player.id];
    return {
      player: player,
      position: positionInfo ? positionInfo.position : null,
      battingOrder: positionInfo ? positionInfo.order : 0,
    };
  }).sort((a, b) => a.battingOrder - b.battingOrder);
});

const initialOpponentLineupForDialog = computed(() => {
  if (opponentStartingMembers.value.length === 0) {
    return [];
  }
  return opponentStartingMembers.value.map(player => {
    const positionInfo = opponentStartingPositions.value[player.id];
    return {
      player: player,
      position: positionInfo ? positionInfo.position : null,
      battingOrder: positionInfo ? positionInfo.order : 0,
    };
  }).sort((a, b) => a.battingOrder - b.battingOrder);
});

const gameResult = computed(() => {
  if (gameData.value.score === null || gameData.value.opponent_score === null) {
    return '';
  }
  if (gameData.value.score > gameData.value.opponent_score) {
    return '勝ち';
  } else if (gameData.value.score < gameData.value.opponent_score) {
    return '負け';
  } else {
    return '引き分け';
  }
});

const homeTeamName = computed(() => {
  if (!gameData.value) return '';
  return gameData.value.home_away === 'home' ? gameData.value.team_name : gameData.value.opponent_team_name;
});

const awayTeamName = computed(() => {
  if (!gameData.value) return '';
  return gameData.value.home_away === 'visitor' ? gameData.value.team_name : gameData.value.opponent_team_name;
});

const homeTeamScore = computed(() => {
  if (!gameData.value.scoreboard?.home) return 0;
  return gameData.value.scoreboard.home.reduce((acc: number, val) => acc + (Number(val) || 0), 0);
});

const awayTeamScore = computed(() => {
  if (!gameData.value.scoreboard?.away) return 0;
  return gameData.value.scoreboard.away.reduce((acc: number, val) => acc + (Number(val) || 0), 0);
});

watch(() => gameData.value.opponent_team_id, (newOpponentId) => {
  if (newOpponentId) {
    const opponentTeam = allTeams.value.find(team => team.id === newOpponentId);
    if (opponentTeam) {
      gameData.value.opponent_team_name = opponentTeam.short_name;
    }
  } else {
    gameData.value.opponent_team_name = '';
  }
});

watch(startingMembers, (newMembers) => {
  const newResults: Record<number, Record<number, string | null>> = {};
  newMembers.forEach(player => {
    if (!player) return;
    newResults[player.id] = {};
    for (let i = 1; i <= 9; i++) {
      newResults[player.id][i] = null;
    }
  });
  battingResults.value = newResults;
}, { deep: true });


const fetchGameData = async () => {
  try {
    const response = await axios.get(`/game/${scheduleId}`);
    gameData.value = response.data;
    if (gameData.value && !gameData.value.scoreboard) {
      gameData.value.scoreboard = {
        home: Array(9).fill(null),
        away: Array(9).fill(null),
      };
    }
    // home team
    if (gameData.value.starting_lineup && gameData.value.starting_lineup.length > 0) {
      const lineup = gameData.value.starting_lineup;
      const members: Player[] = [];
      const positions: Record<number, { position: string, order: number }> = {};

      lineup.forEach(item => {
        const player = players.value.find(p => p.id === item.player_id);
        if (player) {
          members.push(player);
          positions[player.id] = { position: item.position, order: item.order };
        }
      });

      members.sort((a, b) => positions[a.id].order - positions[b.id].order);

      startingMembers.value = members;
      startingPositions.value = positions;
    }
    // opponent team
    if (gameData.value.opponent_starting_lineup && gameData.value.opponent_starting_lineup.length > 0) {
      const lineup = gameData.value.opponent_starting_lineup;
      const members: Player[] = [];
      const positions: Record<number, { position: string, order: number }> = {};

      lineup.forEach(item => {
        const player = allPlayers.value.find(p => p.id === item.player_id);
        if (player) {
          members.push(player);
          positions[player.id] = { position: item.position, order: item.order };
        }
      });

      members.sort((a, b) => positions[a.id].order - positions[b.id].order);

      opponentStartingMembers.value = members;
      opponentStartingPositions.value = positions;
    }
  } catch (error) {
    console.error('Failed to fetch game data:', error);
  }
};

const fetchAllTeams = async () => {
  try {
    const response = await axios.get('/teams');
    allTeams.value = response.data;
  } catch (error) {
    console.error('Failed to fetch teams:', error);
  }
};

const fetchPlayers = async () => {
  if (!teamId) return;
  try {
    const response = await axios.get(`/teams/${teamId}/team_players`);
    players.value = response.data;
  } catch (error) {
    console.error('Failed to fetch players:', error);
  }
};

const fetchAllPlayers = async () => {
  try {
    const response = await axios.get('/players');
    allPlayers.value = response.data;
  } catch (error) {
    console.error('Failed to fetch all players:', error);
  }
};

const showSnackbar = (text: string, color: string = 'success') => {
  snackbarText.value = text;
  snackbarColor.value = color;
  snackbar.value = true;
};

const handleSaveStartingMembers = async (data: { homeLineup: StartingMember[], opponentLineup: StartingMember[] }) => {
  // home team
  const validHomeMembers = data.homeLineup.filter(m => m.player && m.position);
  const sortedHomeMembers = [...validHomeMembers].sort((a, b) => a.battingOrder - b.battingOrder);
  startingMembers.value = sortedHomeMembers.map(m => m.player).filter((p): p is Player => p !== null);

  const homePositions: Record<number, { position: string, order: number }> = {};
  sortedHomeMembers.forEach(member => {
    if (member.player && member.position) {
      homePositions[member.player.id] = { position: member.position, order: member.battingOrder };
    }
  });
  startingPositions.value = homePositions;

  const homeLineupToSave = sortedHomeMembers.map(member => ({
    player_id: member.player!.id,
    position: homePositions[member.player!.id].position,
    order: homePositions[member.player!.id].order,
  }));

  // opponent team
  const validOpponentMembers = data.opponentLineup.filter(m => m.player && m.position);
  const sortedOpponentMembers = [...validOpponentMembers].sort((a, b) => a.battingOrder - b.battingOrder);
  opponentStartingMembers.value = sortedOpponentMembers.map(m => m.player).filter((p): p is Player => p !== null);

  const opponentPositions: Record<number, { position: string, order: number }> = {};
  sortedOpponentMembers.forEach(member => {
    if (member.player && member.position) {
      opponentPositions[member.player.id] = { position: member.position, order: member.battingOrder };
    }
  });
  opponentStartingPositions.value = opponentPositions;

  const opponentLineupToSave = sortedOpponentMembers.map(member => ({
    player_id: member.player!.id,
    position: opponentPositions[member.player!.id].position,
    order: opponentPositions[member.player!.id].order,
  }));

  if (homeLineupToSave.length === 0) {
    showSnackbar('保存するメンバーがいません', 'warning');
    return;
  }

  try {
    await axios.patch(`/game/${scheduleId}`, {
      starting_lineup: homeLineupToSave,
      opponent_starting_lineup: opponentLineupToSave,
    });
    showSnackbar(t('messages.startingMembersSaved'));
  } catch (error) {
    console.error('Failed to save starting members:', error);
    showSnackbar(t('messages.failedToSaveStartingMembers'), 'error');
  }
};

const getPosition = (playerId: number) => {
  return startingPositions.value[playerId]?.order;
};

const getPositionName = (playerId: number) => {
  return t('baseball.shortPositions.' + startingPositions.value[playerId]?.position);
};

const formattedGameDate = computed(() => {
  if (!gameData.value || !gameData.value.game_date) return '';
  const date = new Date(gameData.value.game_date);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  const weekday = date.toLocaleDateString('ja-JP', { weekday: 'short' });
  return t('gameResult.dateDisplay', { month, day, weekday });
});

onMounted(async () => {
  await fetchAllTeams();
  await fetchPlayers();
  await fetchAllPlayers();
  await fetchGameData();
});
</script>

<style scoped>
.scoreboard-table {
  margin-top: 24px;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  overflow: hidden; /* for border-radius */
}

.scoreboard-table th {
  background-color: #fafafa;
  font-weight: 600;
  color: #424242;
  border-bottom: 1px solid #e0e0e0;
  font-size: 0.9rem;
  text-align: center;
}

.scoreboard-table .team-name-header {
  text-align: left;
  border-right: 1px solid #e0e0e0;
  width: 160px;
  padding-left: 16px;
}

.scoreboard-table .inning-header {
  text-align: center;
  border-right: 1px solid #e0e0e0;
}

.scoreboard-table .total-header {
  font-weight: 700;
}

.scoreboard-table td {
  font-size: 1.1rem;
  font-family: 'Roboto Mono', monospace;
  text-align: center;
  border-bottom: 1px solid #eee;
}

.scoreboard-table .team-name {
  text-align: left;
  font-weight: 500;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  padding-left: 16px;
  border-right: 1px solid #e0e0e0;
  font-size: 1rem;
}

.scoreboard-table .inning-score {
  min-width: 48px;
  border-right: 1px solid #e0e0e0;
}

.scoreboard-table .total-score {
  font-weight: 700;
  background-color: #f5f5f5;
  color: #212121;
}

.batting-record-table th {
  text-align: center !important;
  font-weight: 600;
  background-color: #f5f5f5;
}

.batting-record-table td {
  text-align: center;
  min-width: 60px;
}

.inning-result-select {
  min-width: 100px;
}
</style>