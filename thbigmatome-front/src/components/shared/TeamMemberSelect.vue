<template>
  <v-autocomplete
    v-model="selectedPlayer"
    :items="teamMembers"
    item-title="name"
    item-value="id"
  ></v-autocomplete>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import axios from 'axios';

interface TeamMember {
  team_membership_id: number;
  player_name: string;
}

const props = defineProps({
  teamId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['player-selected']);

const teamMembers = ref<TeamMember[]>([]);
const selectedPlayer = ref<number | null>(null);

const fetchTeamMembers = async () => {
  try {
    const response = await axios.get(`/teams/${props.teamId}/team_memberships`);
    console.log(response)
    teamMembers.value = response.data
  } catch (error) {
    console.error('Failed to fetch team members:', error);
  }
};

onMounted(fetchTeamMembers);

defineExpose({
  selectedPlayer,
});
</script>

<style scoped>
</style>