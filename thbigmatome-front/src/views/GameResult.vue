<template>
  <v-container>

    <v-toolbar
      color="orange-lighten-3"
    >
      <template #prepend>
        <span class="text-h5 mx-4">{{ gameData.team_name }}</span>
        <span class="text-h6 mx-4">{{ t('gameResult.game') }}: {{ gameData.game_number }}</span>
        <span class="text-h6 mx-4">{{ formattedGameDate }}</span>
      </template>
      <v-btn
        class="mx-2"
        color="light"
        variant="flat"
        :to="seasonPortalRoute"
      >
        {{ t('seasonPortal.title') }}
      </v-btn>
      <v-btn
        :to="scoreSheetRoute"
        color="info"
        variant="flat"
        class="mr-4"
      >
        スコアシート
      </v-btn>
      <template #append>
        <v-btn
          @click="saveGame"
          color="primary"
          variant="flat"
          prepend-icon="mdi-content-save-outline"
        >
          {{ t('gameResult.save') }}
        </v-btn>
      </template>
    </v-toolbar>

    <v-row>
      <v-col>
        <v-card>
          <v-card-title>{{ t('gameResult.basicInfo') }}</v-card-title>
          <v-card-text >
            <v-row>
              <v-col>
                <TeamMemberSelect
                  v-model="gameData.announced_starter_id"
                  :team-id="gameData.team_id"
                  v-if="gameData.team_id"
                  :label="t('gameResult.announcedStarter')"
                />
              </v-col>
              <v-col>
                <TeamSelect
                  v-model="gameData.opponent_team_id"
                  :teams="allTeams"
                  display-name-type="short_name"
                  :label="t('gameResult.opponentTeam')" />
              </v-col>
              <v-col>
                <v-select
                  v-model="gameData.home_away"
                  :items="homeAwayItems"
                  item-title="name"
                  item-value="value"
                  :label="t('gameResult.homeAway.title')"
                >
                </v-select>
              </v-col>
              <v-col>
                <v-text-field
                  v-model="gameData.stadium"
                  :label="t('gameResult.stadium')"
                >
                </v-text-field>
              </v-col>
              <v-col>
                <v-select
                  v-model="gameData.designated_hitter_enabled"
                  :items="dhItems"
                  item-title="name"
                  item-value="value"
                  :label="t('gameResult.dhSystem.title')"
                >
                </v-select>
              </v-col>
            </v-row>
          </v-card-text>
          <v-card-title>{{ t('gameResult.gameInfo') }}</v-card-title>
          <v-card-text>
            <Scoreboard
              v-if="gameData.scoreboard"
              v-model="gameData.scoreboard"
              :home-team-name="homeTeamName"
              :away-team-name="awayTeamName"
            />
            <v-row class="mt-4">
              <v-col>
                <PlayerSelect
                  v-model="gameData.winning_pitcher_id"
                  :players="allPlayers"
                  :label="t('gameResult.winningPitcher')"
                />
              </v-col>
              <v-col>
                <PlayerSelect
                  v-model="gameData.losing_pitcher_id"
                  :players="allPlayers"
                  :label="t('gameResult.losingPitcher')"
                />
              </v-col>
              <v-col>
                <PlayerSelect
                  v-model="gameData.save_pitcher_id"
                  :players="allPlayers"
                  :label="t('gameResult.savePitcher')"
                />
              </v-col>
            </v-row>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
    <v-snackbar
      v-model="snackbar"
      :color="snackbarColor"
      :timeout="3000"
    >
      {{ snackbarText }}
    </v-snackbar>
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
import TeamMemberSelect from '@/components/shared/TeamMemberSelect.vue';
import TeamSelect from '@/components/shared/TeamSelect.vue';
import PlayerSelect from '@/components/shared/PlayerSelect.vue';
import Scoreboard from '@/components/Scoreboard.vue';

const { t } = useI18n();
const route = useRoute();
const gameDate = ref(new Date());

const snackbar = ref(false);
const snackbarText = ref('');
const snackbarColor = ref('success');

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
  }
}

const seasonPortalRoute = computed(() => {
  return {
    name: 'SeasonPortal',
    params: {
      teamId: teamId
    }
  };
});

const scoreSheetRoute = computed(() => {
  return {
    name: 'ScoreSheet',
    params: {
      teamId: teamId,
      scheduleId: scheduleId
    }
  };
});

const gameData = ref<GameData>(defaultGameData)
const allPlayers = ref<Player[]>([]);
const allTeams = ref<Team[]>([]);

const homeAwayItems = [
  { name: t('gameResult.homeAway.home'), value: 'home' },
  { name: t('gameResult.homeAway.away'), value: 'visitor' }
]

const dhItems = [
  { name: t('gameResult.dhSystem.enabled'), value: true },
  { name: t('gameResult.dhSystem.disabled'), value: false }
]

const homeTeamName = computed(() => {
  if (!gameData.value) return '';
  return gameData.value.home_away === 'home' ? gameData.value.team_name : gameData.value.opponent_team_name;
});

const awayTeamName = computed(() => {
  if (!gameData.value) return '';
  return gameData.value.home_away === 'visitor' ? gameData.value.team_name : gameData.value.opponent_team_name;
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

const fetchSeason = async () => {
  try {
    const response = await axios.get(`/game/${scheduleId}`);
    gameData.value = response.data;
    if (gameData.value) {
      gameDate.value = new Date(gameData.value.game_date);
      if (!gameData.value.scoreboard) {
        gameData.value.scoreboard = {
          home: Array(9).fill(null),
          away: Array(9).fill(null),
        };
      }
    }
  } catch (error) {
    console.error('Failed to fetch season data:', error);
  }
};

const fetchAllPlayers = async () => {
  try {
    const response = await axios.get('/players');
    allPlayers.value = response.data;
  } catch (error) {
    console.error('Failed to fetch players:', error);
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

const showSnackbar = (text: string, color: string = 'success') => {
  snackbarText.value = text;
  snackbarColor.value = color;
  snackbar.value = true;
};

const saveGame = async () => {
  if (!gameData.value.scoreboard) return;

  const homeTeamScore = gameData.value.scoreboard.home.reduce((acc: number, val) => acc + (Number(val) || 0), 0);
  const awayTeamScore = gameData.value.scoreboard.away.reduce((acc: number, val) => acc + (Number(val) || 0), 0);

  const isScoreboardEmpty = (scoreboardArray: (number | null)[]) => {
    return scoreboardArray.every(val => val === null || val === 0);
  };

  const homeScoreboardEmpty = isScoreboardEmpty(gameData.value.scoreboard.home);
  const awayScoreboardEmpty = isScoreboardEmpty(gameData.value.scoreboard.away);

  if (homeScoreboardEmpty && awayScoreboardEmpty) {
    gameData.value.score = null;
    gameData.value.opponent_score = null;
  } else if (gameData.value.home_away === 'home') {
    gameData.value.score = homeTeamScore;
    gameData.value.opponent_score = awayTeamScore;
  } else {
    gameData.value.score = awayTeamScore;
    gameData.value.opponent_score = homeTeamScore;
  }

  try {
    await axios.put(`/game/${scheduleId}`, gameData.value);
    showSnackbar(t('gameResult.saveSuccess'));
  } catch (error) {
    console.error('Failed to save game data:', error);
    showSnackbar(t('gameResult.saveFailed'), 'error');
  }
};

const formattedGameDate = computed(() => {
  const date = new Date(gameData.value.game_date);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  const weekday = date.toLocaleDateString('ja-JP', { weekday: 'short' });
  return t('gameResult.dateDisplay', { month, day, weekday });
});

onMounted(() => {
  fetchSeason();
  fetchAllPlayers();
  fetchAllTeams();
});

</script>
