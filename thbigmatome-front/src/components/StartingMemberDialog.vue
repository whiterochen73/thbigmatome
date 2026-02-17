<template>
  <v-dialog :model-value="modelValue" @update:model-value="$emit('update:modelValue', $event)" persistent max-width="1200px">
    <v-card>
      <v-card-title>
        <span class="text-h5">{{ t('startingMemberDialog.title') }}</span>
      </v-card-title>
      <v-card-text>
        <v-row>
          <v-col cols="12" md="6">
            <h3 class="text-h6">{{ t('startingMemberDialog.homeTeamLineup') }}</h3>
            <v-table>
              <thead>
                <tr>
                  <th class="text-left">{{ t('startingMemberDialog.tableHeaders.battingOrder') }}</th>
                  <th class="text-left">{{ t('startingMemberDialog.tableHeaders.position') }}</th>
                  <th class="text-left">{{ t('startingMemberDialog.tableHeaders.player') }}</th>
                  <th class="text-left">{{ t('startingMemberDialog.tableHeaders.defenseRating') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="member in homeLineup" :key="member.battingOrder">
                  <td>{{ member.battingOrder }}</td>
                  <td style="width: 150px;">
                    <v-select
                      v-model="member.position"
                      :items="availablePositions(member.position, homeLineup)"
                      item-title="name"
                      item-value="key"
                      dense
                      hide-details
                      @keydown="handlePositionKeydown(member, homeLineup, $event)"
                    ></v-select>
                  </td>
                  <td>
                    <v-autocomplete
                      v-model="member.player"
                      :items="homeTeamPlayers"
                      :item-props="playerItemProps"
                      return-object
                      dense
                      hide-details
                    ></v-autocomplete>
                  </td>
                  <td>{{ getDefenseRating(member) }}</td>
                </tr>
              </tbody>
            </v-table>
          </v-col>
          <v-col cols="12" md="6">
            <h3 class="text-h6">{{ t('startingMemberDialog.opponentTeamLineup') }}</h3>
            <v-table>
              <thead>
                <tr>
                  <th class="text-left">{{ t('startingMemberDialog.tableHeaders.battingOrder') }}</th>
                  <th class="text-left">{{ t('startingMemberDialog.tableHeaders.position') }}</th>
                  <th class="text-left">{{ t('startingMemberDialog.tableHeaders.player') }}</th>
                  <th class="text-left">{{ t('startingMemberDialog.tableHeaders.defenseRating') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="member in opponentLineup" :key="member.battingOrder">
                  <td>{{ member.battingOrder }}</td>
                  <td style="width: 150px;">
                    <v-select
                      v-model="member.position"
                      :items="availablePositions(member.position, opponentLineup)"
                      item-title="name"
                      item-value="key"
                      dense
                      hide-details
                      @keydown="handlePositionKeydown(member, opponentLineup, $event)"
                    ></v-select>
                  </td>
                  <td>
                    <v-autocomplete
                      v-model="member.player"
                      :items="allPlayers"
                      :item-props="playerItemProps"
                      return-object
                      dense
                      hide-details
                    ></v-autocomplete>
                  </td>
                  <td>{{ getDefenseRating(member) }}</td>
                </tr>
              </tbody>
            </v-table>
          </v-col>
        </v-row>
      </v-card-text>
      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn color="blue-darken-1" variant="text" @click="closeDialog">{{ t('actions.cancel') }}</v-btn>
        <v-btn color="blue-darken-1" variant="text" @click="saveLineup">{{ t('actions.save') }}</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref, watch, type PropType } from 'vue';
import { useI18n } from 'vue-i18n';
import axios from 'axios';
import type { Player } from '@/types/player';

const { t } = useI18n();

interface LineupMember {
  battingOrder: number;
  position: string | null;
  player: Player | null;
}

const props = defineProps({
  modelValue: {
    type: Boolean,
    required: true,
  },
  homeTeamId: {
    type: Number,
    required: true,
  },
  allPlayers: {
    type: Array as PropType<Player[]>,
    default: () => [],
  },
  initialHomeLineup: {
    type: Array as PropType<LineupMember[]>,
    default: () => [],
  },
  initialOpponentLineup: {
    type: Array as PropType<LineupMember[]>,
    default: () => [],
  },
  designatedHitterEnabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:modelValue', 'save']);

const homeTeamPlayers = ref<Player[]>([]);
const homeLineup = ref<LineupMember[]>([]);
const opponentLineup = ref<LineupMember[]>([]);

const playerItemProps = (item: Player) => {
  return {
    title: `${item.number} ${item.name}`,
  };
};

const positionOptions = [
  { key: 'p', name: t('baseball.positions.pitcher'), defenseKey: 'defense_p' },
  { key: 'c', name: t('baseball.positions.catcher'), defenseKey: 'defense_c' },
  { key: '1b', name: t('baseball.positions.first_baseman'), defenseKey: 'defense_1b' },
  { key: '2b', name: t('baseball.positions.second_baseman'), defenseKey: 'defense_2b' },
  { key: '3b', name: t('baseball.positions.third_baseman'), defenseKey: 'defense_3b' },
  { key: 'ss', name: t('baseball.positions.shortstop'), defenseKey: 'defense_ss' },
  { key: 'lf', name: t('baseball.positions.left_fielder'), defenseKey: 'defense_lf' },
  { key: 'cf', name: t('baseball.positions.center_fielder'), defenseKey: 'defense_cf' },
  { key: 'rf', name: t('baseball.positions.right_fielder'), defenseKey: 'defense_rf' },
];

const dhPosition = { key: 'dh', name: t('baseball.positions.dh'), defenseKey: null };

const initializeLineup = () => {
  const size = props.designatedHitterEnabled ? 10 : 9;

  // Initialize home lineup
  const newHomeLineup: LineupMember[] = [];
  for (let i = 1; i <= size; i++) {
    const savedMember = props.initialHomeLineup.find(m => m.battingOrder === i);
    if (savedMember) {
      newHomeLineup.push(JSON.parse(JSON.stringify(savedMember)));
    } else {
      newHomeLineup.push({ battingOrder: i, position: null, player: null });
    }
  }
  homeLineup.value = newHomeLineup;

  // Initialize opponent lineup
  const newOpponentLineup: LineupMember[] = [];
  for (let i = 1; i <= size; i++) {
    const savedMember = props.initialOpponentLineup.find(m => m.battingOrder === i);
    if (savedMember) {
      newOpponentLineup.push(JSON.parse(JSON.stringify(savedMember)));
    } else {
      newOpponentLineup.push({ battingOrder: i, position: null, player: null });
    }
  }
  opponentLineup.value = newOpponentLineup;
};

const availablePositions = (currentPositionKey: string | null, targetLineup: LineupMember[]) => {
  let allPositions = [...positionOptions];
  if (props.designatedHitterEnabled) {
    allPositions.push(dhPosition);
  } else {
    // DH制でない場合、投手は打順に入るので、投手以外のポジションからDHを除外
    allPositions = allPositions.filter(p => p.key !== 'dh');
  }

  const usedPositions = targetLineup
    .map(m => m.position)
    .filter(p => p !== null && p !== currentPositionKey);

  return allPositions.filter(p => !usedPositions.includes(p.key));
};

const fetchHomeTeamPlayers = async () => {
  if (!props.homeTeamId) return;
  try {
    const response = await axios.get(`/teams/${props.homeTeamId}/team_players`);
    homeTeamPlayers.value = response.data;
  } catch (error) {
    console.error('Failed to fetch home team players:', error);
  }
};

const getDefenseRating = (member: LineupMember): string => {
  if (!member.player || !member.position) return '-';

  const positionInfo = positionOptions.find(p => p.key === member.position);
  if (!positionInfo) {
    if (member.position === 'dh') return '-';
    return '-';
  }

  let defenseValue: string | number | undefined;
  let throwingValue: string | number | undefined;

  // Handle outfield positions with OF fallback
  if (['lf', 'cf', 'rf'].includes(member.position)) {
    const specificDefenseKey = positionInfo.defenseKey as keyof Player;
    defenseValue = <string | number | undefined>member.player[specificDefenseKey];
    if (!defenseValue) {
      defenseValue = member.player.defense_of; // Fallback to defense_of
    }
    throwingValue = member.player.throwing_of; // Use throwing_of for all outfielders
  } else if (member.position === 'c') {
    defenseValue =  <string | number | undefined>member.player[positionInfo.defenseKey as keyof Player];
    // Format throwing_c: if it's a number, prefix with '+' if positive
    if (typeof member.player.throwing_c === 'number') {
      throwingValue = member.player.throwing_c > 0 ? `+${member.player.throwing_c}` : String(member.player.throwing_c);
    } else {
      throwingValue = member.player.throwing_c; // If it's not a number, use as is (might be undefined)
    }
  } else {
    defenseValue =  <string | number | undefined>member.player[positionInfo.defenseKey as keyof Player];
  }

  let result = defenseValue ? String(defenseValue) : '-';

  if (throwingValue !== undefined && throwingValue !== null) {
    result += `/${throwingValue}`;
  }

  return result;
};

const positionShortcuts: { [key: string]: string } = {
  '1': 'p',
  'p': 'p',
  'P': 'p',
  '2': 'c',
  '3': '1b',
  '4': '2b',
  '5': '3b',
  '6': 'ss',
  '7': 'lf',
  '8': 'cf',
  '9': 'rf',
  '0': 'dh',
  'd': 'dh',
  'D': 'dh',
};

const handlePositionKeydown = (member: LineupMember, lineup: LineupMember[], event: KeyboardEvent) => {
  const key = event.key.toLowerCase();
  if (positionShortcuts[key]) {
    const newPositionKey = positionShortcuts[key];
    // Check if the new position is available for selection within the specific lineup
    const available = availablePositions(member.position, lineup).some(
      (pos) => pos.key === newPositionKey
    );
    if (available) {
      member.position = newPositionKey;
      event.preventDefault(); // Prevent default behavior
    }
  }
};

const closeDialog = () => {
  emit('update:modelValue', false);
};

const saveLineup = () => {
  emit('save', { homeLineup: homeLineup.value, opponentLineup: opponentLineup.value });
  closeDialog();
};

watch(() => props.modelValue, (newVal) => {
  if (newVal) {
    initializeLineup();
    fetchHomeTeamPlayers();
  }
});

// Remove the old watch for props.teamId as it's replaced by props.homeTeamId and fetchHomeTeamPlayers
// watch(() => props.teamId, (newVal) => {
//   if (newVal) {
//     fetchTeamPlayers();
//   }
// }, { immediate: true });

</script>