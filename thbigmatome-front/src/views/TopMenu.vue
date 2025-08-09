<template>
  <v-container>
    <v-row justify="center">
      <v-col cols="12" md="8">
        <v-card>
          <v-card-item>
            <v-card-title class="text-h5">{{ t('topMenu.welcome.title') }}</v-card-title>
            <v-card-subtitle>{{ t('topMenu.welcome.subtitle') }}</v-card-subtitle>
          </v-card-item>
          <v-card-text>
            <p>{{ t('topMenu.welcome.message') }}</p>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
    <v-row justify="center" class="mt-4">
      <v-col cols="12" md="8">
        <v-card>
          <v-card-item>
            <v-card-title>{{ t('topMenu.teamSelection.title') }}</v-card-title>
            <v-card-subtitle v-if="manager">{{ t('topMenu.teamSelection.managerName', { name: manager.name }) }}</v-card-subtitle>
          </v-card-item>
          <v-card-text>
            <div v-if="teams.length > 0">
              <v-select
                v-model="selectedTeam"
                :items="teams"
                item-title="name"
                item-value="id"
                :label="t('topMenu.teamSelection.selectLabel')"
                return-object
              ></v-select>
              <v-btn v-if="selectedTeam" color="primary" @click="goToTeamMembers" class="mt-4">
                {{ t('topMenu.teamSelection.registerMembers') }}
              </v-btn>
            </div>
            <div v-else>
              <p>{{ t('topMenu.teamSelection.noTeams') }}</p>
              <v-btn color="primary" @click="addTeam" class="mt-4">{{ t('topMenu.teamSelection.addTeam') }}</v-btn>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
    <TeamDialog
      v-model:isVisible="teamDialog"
      :team="null"
      :default-manager-id="manager?.id"
      @save="handleSave" />
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAuth } from '@/composables/useAuth';
import axios from 'axios';
import type { Manager } from '@/types/manager';
import type { Team } from '@/types/team';
import TeamDialog from '@/components/TeamDialog.vue';
import { useRouter } from 'vue-router';

const { t } = useI18n();
const { user } = useAuth();
const router = useRouter();

const managers = ref<Manager[]>([]);
const teams = ref<Team[]>([]);
const selectedTeam = ref<Team | null>(null);
const manager = ref<Manager | null>(null);
const teamDialog = ref(false);

const addTeam = () => {
  teamDialog.value = true;
};

const selectTeam = (team: Team) => {
  selectedTeam.value = team;
  // ここで選択されたチームに関するロジックを追加できます
  console.log('Selected team:', team);
};

const goToTeamMembers = () => {
  if (selectedTeam.value) {
    router.push({ name: 'TeamMembers', params: { teamId: selectedTeam.value.id } });
  }
};

const fetchManagers = async () => {
  try {
    const response = await axios.get('/managers');
    managers.value = response.data;
    if (user.value) {
      manager.value = managers.value.find(m => m.user_id == user.value?.id) || null;
      if (manager.value) {
        fetchTeams(manager.value.id);
      }
    }
  } catch (error) {
    console.error('Failed to fetch managers:', error);
  }
};

const fetchTeams = async (managerId: number) => {
  try {
    const response = await axios.get(`/managers/${managerId}/teams`);
    teams.value = response.data;
  } catch (error) {
    console.error('Failed to fetch teams:', error);
  }
};

const handleSave = () => {
  if (manager.value) {
    fetchTeams(manager.value.id);
  }
  teamDialog.value = false;
};

onMounted(() => {
  fetchManagers();
});
</script>
