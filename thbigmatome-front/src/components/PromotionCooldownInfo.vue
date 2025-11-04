<template>
  <v-row>
    <v-col>
      <v-alert
        variant="tonal"
        :color="cooldownPlayers.length === 0 ? 'primary' : 'orange-darken-3'"
        border-color="warning"
        density="compact"
        elevation="2"
      >
        <template #prepend>
          <v-icon>mdi-timer-sand</v-icon>
        </template>
        <template #title>
          <div class="d-flex justify-space-between align-center">
            <span>{{ t('activeRoster.cooldownInfo') }} ({{ currentDateStr }})</span>
          </div>
        </template>
        <div v-if="cooldownPlayers.length > 0">
          <p v-for="player in cooldownPlayers" :key="player.team_membership_id" class="mb-0">
            {{ getCooldownDisplayText(player) }}
          </p>
        </div>
        <div v-else>
          {{ t('activeRoster.noCooldownInfo') }}
        </div>
      </v-alert>
    </v-col>
  </v-row>
</template>

<script setup lang="ts">
import { computed, defineProps } from 'vue';
import { useI18n } from 'vue-i18n';
import type { RosterPlayer } from '@/types/rosterPlayer';

const { t } = useI18n();

const props = defineProps<{
    cooldownPlayers: RosterPlayer[];
    currentDate: string;
}>();

const currentDateStr = computed(() => {
  return new Date(props.currentDate).toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' });
});

const getCooldownDisplayText = (player: RosterPlayer) => {
  if (!player.cooldown_until) return '';
  const cooldownDate = new Date(player.cooldown_until);
  const formattedCooldownDate = cooldownDate.toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' });
  return `${player.player_name}: ${t('activeRoster.cooldownUntil', { date: formattedCooldownDate })}`;
};
</script>