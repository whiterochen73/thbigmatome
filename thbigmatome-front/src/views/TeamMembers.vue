<template>
  <v-container>
    <v-row>
      <v-col>
        <h1 class="text-h4">{{ t('teamMembers.title', { teamName: team.name }) }}</h1>
      </v-col>
    </v-row>

    <!-- Cost List & Player Selection -->
    <v-row class="mb-4">
      <v-col cols="12" md="4">
        <CostListSelect
          v-model="selectedCost"
          :label="t('teamMembers.selectCostList')"
        />
      </v-col>
      <v-col cols="12" md="6">
        <v-autocomplete
          v-model="selectedPlayer"
          :items="availablePlayers"
          :item-title="player => `${player.number} ${player.name}`"
          item-value="id"
          :label="t('teamMembers.selectPlayer')"
          return-object
          clearable
          :disabled="!selectedCostListId"
        />
      </v-col>
      <v-col cols="12" md="2">
        <v-btn color="primary" @click="addPlayer" :disabled="!selectedPlayer || !selectedCostListId">
          {{ t('teamMembers.addPlayer') }}
        </v-btn>
      </v-col>
    </v-row>

    <!-- Team Members Table -->
    <v-row>
      <v-col cols="12">
        <v-card>
          <v-card-title class="d-flex justify-space-between">
            <span>{{ t('teamMembers.teamMembersTitle') }}</span>
            <div class="text-subtitle-1">
              <span>{{ t('teamMembers.totalCount', { count: teamPlayers.length, max: MAX_PLAYERS }) }} / </span>
              <span>{{ t('teamMembers.totalCost', { cost: totalTeamCost, max: TOTAL_TEAM_MAX_COST }) }}</span>
            </div>
          </v-card-title>
          <v-data-table
            :headers="headers"
            :items="teamPlayers"
            :no-data-text="t('teamMembers.noData')"
          >
            <template #item.position="{ item }">
              {{ t(`baseball.positions.${item.position}`) }}
            </template>
            <template #item.cost="{ item }">
              <div class="d-flex align-center">
                <v-select
                  v-model="item.selected_cost_type"
                  :items="getAvailableCostTypes(item)"
                  item-title="text"
                  item-value="value"
                  dense
                  hide-details
                  @update:modelValue="updatePlayerCost(item)"
                ></v-select>
              </div>
            </template>
            <template #item.actions="{ item }">
              <v-btn icon="mdi-delete" size="small" variant="text" @click="removePlayer(item)" />
            </template>
          </v-data-table>
        </v-card>
      </v-col>
    </v-row>

    <!-- Actions -->
    <v-row>
      <v-col class="d-flex justify-end mt-4">
        <v-btn @click="goBack" class="mr-4">{{ t('actions.cancel') }}</v-btn>
        <v-btn color="primary" @click="saveTeamMembers">{{ t('actions.save') }}</v-btn>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import axios from '@/plugins/axios';
import { useSnackbar } from '@/composables/useSnackbar';
import type { Player } from '@/types/player';
import type { Team } from '@/types/team';
import type { CostList } from '@/types/costList'
import CostListSelect from '@/components/shared/CostListSelect.vue'

type CostType = 'normal_cost' | 'relief_only_cost' | 'pitcher_only_cost' | 'fielder_only_cost' | 'two_way_cost';

interface TeamPlayer extends Player {
  selected_cost_type: CostType;
  current_cost: number;
}

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { showSnackbar } = useSnackbar();

const team = ref<Partial<Team>>({});
const allPlayers = ref<Player[]>([]);
const teamPlayers = ref<TeamPlayer[]>([]);
const selectedCost = ref<CostList | null>(null)
const selectedCostListId = computed(() => selectedCost.value ? selectedCost.value.id : null);
const selectedPlayer = ref<Player | null>(null);

const teamId = computed(() => Number(route.params.teamId));

// Squad limits
const MAX_PLAYERS = 50;
const TOTAL_TEAM_MAX_COST = 200;

const headers = computed(() => [
  { title: t('teamMembers.headers.number'), value: 'number' },
  { title: t('teamMembers.headers.name'), value: 'name' },
  { title: t('teamMembers.headers.position'), value: 'position' },
  { title: t('teamMembers.headers.cost'), value: 'cost' },
  { title: t('teamMembers.headers.actions'), value: 'actions', sortable: false, width: '100px' },
]);

// --- Computed properties ---
const totalTeamCost = computed(() => {
  return teamPlayers.value.reduce((sum, p) => {
    const costPlayerForSelectedList = p.cost_players.find(cp => cp.cost_id === selectedCostListId.value);
    const costValue = costPlayerForSelectedList ? ((costPlayerForSelectedList as Record<CostType, number | null>)[p.selected_cost_type] ?? 0) : 0;
    return sum + costValue;
  }, 0);
});

const availablePlayers = computed(() => {
  if (!selectedCostListId.value) return [];
  // 選択されたコスト一覧表にnormal_costが設定されている選手のみをフィルタリング
  return allPlayers.value.filter(p => {
    const costPlayer = p.cost_players.find(cp => cp.cost_id === selectedCostListId.value);
    return costPlayer && costPlayer.normal_cost !== null && !teamPlayers.value.some(tp => tp.id === p.id);
  });
});

// --- API Calls ---
const fetchTeam = async () => {
  try {
    const response = await axios.get<Team>(`/teams/${teamId.value}`);
    team.value = response.data;
  } catch (error) {
    showSnackbar(t('teamMembers.notifications.fetchTeamFailed'), 'error');
    console.error('Failed to fetch team:', error);
  }
};

const fetchAllPlayers = async () => {
  try {
    const response = await axios.get<Player[]>('/team_registration_players');
    allPlayers.value = response.data;
  } catch (error) {
    showSnackbar(t('teamMembers.notifications.fetchPlayersFailed'), 'error');
    console.error('Failed to fetch players:', error);
  }
};

const fetchTeamPlayers = async () => {
  if (!selectedCostListId.value) return;
  try {
    const response = await axios.get<TeamPlayer[]>(`/teams/${teamId.value}/team_players`);
    teamPlayers.value = response.data.map(player => {
      let initialSelectedCostType: CostType = 'normal_cost'; // Default to normal_cost

      const costPlayerForSelectedList = player.cost_players.find(cp => cp.cost_id === selectedCostListId.value);

      // Determine the initial selected cost type
      const availableOptions = getAvailableCostTypes(player);

      // 1. Try to use the selected_cost_type from backend if it's valid and has a non-null cost
      if (player.selected_cost_type && availableOptions.some(opt => {
        if (!costPlayerForSelectedList) return false;

        const typedCostPlayer = costPlayerForSelectedList as Record<CostType, number | null>;
        return opt.value === player.selected_cost_type && (typedCostPlayer[opt.value] !== null);
      })) {
        initialSelectedCostType = player.selected_cost_type as CostType;
      } else if (costPlayerForSelectedList?.normal_cost !== null) {
        // 2. If not, try normal_cost if it's available
        initialSelectedCostType = 'normal_cost';
      } else if (availableOptions.length > 0) {
        // 3. Otherwise, pick the first available option
        initialSelectedCostType = availableOptions[0].value;
      } else {
        // 4. If no options are available, default to normal_cost (even if null)
        initialSelectedCostType = 'normal_cost';
      }

      // Calculate current_cost based on the determined initialSelectedCostType
      const costValue = costPlayerForSelectedList ? ((costPlayerForSelectedList as Record<CostType, number | null>)[initialSelectedCostType] ?? 0) : 0;

      return {
        ...player,
        selected_cost_type: initialSelectedCostType,
        current_cost: costValue,
      };
    });
  } catch (error) {
    showSnackbar(t('teamMembers.notifications.fetchTeamPlayersFailed'), 'error');
    console.error('Failed to fetch team players:', error);
  }
};

watch(selectedCost, async () => {
  await fetchAllPlayers();
  await fetchTeamPlayers();
});

// --- Player & Cost Management ---

const getAvailableCostTypes = (player: Player) => {
  const options: { value: CostType, text: string }[] = [];
  const costPlayerForSelectedList = player.cost_players.find(cp => cp.cost_id === selectedCostListId.value);

  if (!costPlayerForSelectedList) return []; // 選択されたコスト一覧表に紐づくコストデータがない場合は空を返す

  const addOption = (type: CostType, cost: number | null | undefined) => {
    if (cost !== null && cost !== undefined) {
      options.push({ value: type, text: `${t('teamMembers.costTypes.' + type)} (${cost})` });
    }
  };

  addOption('normal_cost', costPlayerForSelectedList.normal_cost);
  if (player.player_type_ids && player.player_type_ids.includes(9)) addOption('relief_only_cost', costPlayerForSelectedList.relief_only_cost);
  if (player.player_type_ids && player.player_type_ids.includes(8)) {
    addOption('pitcher_only_cost', costPlayerForSelectedList.pitcher_only_cost);
    addOption('fielder_only_cost', costPlayerForSelectedList.fielder_only_cost);
  }
  if (player.player_type_ids && player.player_type_ids.includes(2)) addOption('two_way_cost', costPlayerForSelectedList.two_way_cost);

  return options;
};

const updatePlayerCost = (player: TeamPlayer) => {
  const costPlayerForSelectedList = player.cost_players.find(cp => cp.cost_id === selectedCostListId.value);
  const costValue = costPlayerForSelectedList ? (costPlayerForSelectedList[player.selected_cost_type] ?? 0) : 0;
  player.current_cost = costValue;
};

const addPlayer = () => {
  if (!selectedPlayer.value) return;

  if (teamPlayers.value.some(p => p.id === selectedPlayer.value!.id)) {
    showSnackbar(t('teamMembers.notifications.playerAlreadyAdded'), 'warning');
    return;
  }

  const costPlayerForSelectedList = selectedPlayer.value.cost_players.find(cp => cp.cost_id === selectedCostListId.value);
  const initialCostType: CostType = 'normal_cost';
  const initialCost = costPlayerForSelectedList ? (costPlayerForSelectedList.normal_cost ?? 0) : 0;

  const newPlayer: TeamPlayer = {
    ...selectedPlayer.value,
    selected_cost_type: initialCostType,
    current_cost: initialCost,
  };

  teamPlayers.value.push(newPlayer);
  selectedPlayer.value = null;

  // Check limits and show warnings
  if (teamPlayers.value.length > MAX_PLAYERS) {
    showSnackbar(t('teamMembers.notifications.maxPlayersExceeded', { max: MAX_PLAYERS }), 'warning');
  }
  if (totalTeamCost.value > TOTAL_TEAM_MAX_COST) {
    showSnackbar(t('teamMembers.notifications.totalCostExceeded', { max: TOTAL_TEAM_MAX_COST }), 'warning');
  }
};

const removePlayer = (player: TeamPlayer) => {
  teamPlayers.value = teamPlayers.value.filter(p => p.id !== player.id);
};

// --- Actions ---
const saveTeamMembers = async () => {
  if (!selectedCostListId.value) {
      showSnackbar(t('teamMembers.notifications.selectCostList'), 'error');
      return;
  }
  try {
    const payload = {
      cost_list_id: selectedCostListId.value,
      players: teamPlayers.value.map(p => ({
        player_id: p.id,
        selected_cost_type: p.selected_cost_type,
      }))
    };
    await axios.post(`/teams/${teamId.value}/team_players`, payload);
    showSnackbar(t('teamMembers.notifications.saveSuccess'), 'success');
  } catch (error) {
    showSnackbar(t('teamMembers.notifications.saveFailed'), 'error');
    console.error('Failed to save team members:', error);
  }
};

const goBack = () => {
  router.back();
};

onMounted(async () => {
  await fetchTeam();
});

</script>