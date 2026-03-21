<template>
  <v-autocomplete
    :model-value="modelValue"
    @update:model-value="emit('update:modelValue', $event)"
    :items="teamMembers"
    item-title="name"
    item-value="id"
    :label="label"
    v-bind="$attrs"
  ></v-autocomplete>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import axios from 'axios'

interface TeamMember {
  id: number
  name: string
  player_id: number
}

const props = defineProps<{
  teamId: number
  modelValue?: number | null
  label?: string
  starterEligible?: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: number | null]
}>()

const teamMembers = ref<TeamMember[]>([])

const fetchTeamMembers = async () => {
  if (!props.teamId) return
  try {
    const params = props.starterEligible ? { filter: 'starter_eligible' } : {}
    const response = await axios.get(`/teams/${props.teamId}/team_memberships`, { params })
    teamMembers.value = response.data
  } catch (error) {
    console.error('Failed to fetch team members:', error)
  }
}

onMounted(fetchTeamMembers)
watch(() => props.teamId, fetchTeamMembers)
</script>
