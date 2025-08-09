<template>
  <v-container fluid>
    <v-row>
      <v-col cols="12">
        <h1>{{ $t('settings.title') }}</h1>
        <p class="mt-4">{{ $t('settings.description') }}</p>
      </v-col>
    </v-row>
    <v-row>
      <v-col cols="12">
        <v-tabs color="primary" slider-color="accent" v-model="selectedTab">
          <v-tab value="player">{{ $t('settings.tabs.player') }}</v-tab>
          <v-tab value="squad">{{ $t('settings.tabs.squad') }}</v-tab>
        </v-tabs>

        <v-card>
          <v-tabs-window v-model="selectedTab">
            <v-tabs-window-item value="player">
              <v-row>
                <v-col cols="12">
                  <p>{{ $t('settings.player.description') }}</p>
                </v-col>
              </v-row>
              <v-row>
                <v-col cols="12" md="8" lg="6">
                  <PitchingStyleSettings />
                  <div class="mt-6"></div>
                  <PitchingSkillSettings />
                  <div class="mt-6"></div>
                  <PlayerTypeSettings />
                </v-col>
                <v-col cols="12" md="8" lg="6">
                  <BattingStyleSettings />
                  <div class="mt-6"></div>
                  <BattingSkillSettings />
                  <div class="mt-6"></div>
                  <BiorhythmSettings />
                </v-col>
              </v-row>
            </v-tabs-window-item>
            <v-tabs-window-item value="squad">
              <v-row>
                <v-col cols="6">
                  <CostSettings />
                </v-col>
                <v-col cols="6">
                  <ScheduleSettings />
                </v-col>
              </v-row>
            </v-tabs-window-item>
          </v-tabs-window>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import PitchingStyleSettings from '@/components/settings/PitchingStyleSettings.vue';
import PitchingSkillSettings from '@/components/settings/PitchingSkillSettings.vue';
import BattingStyleSettings from '@/components/settings/BattingStyleSettings.vue';
import BattingSkillSettings from '@/components/settings/BattingSkillSettings.vue';
import PlayerTypeSettings from '@/components/settings/PlayerTypeSettings.vue';
import BiorhythmSettings from '@/components/settings/BiorhythmSettings.vue';
import CostSettings from '@/components/settings/CostSettings.vue';
import ScheduleSettings from '@/components/settings/ScheduleSettings.vue';

const { t } = useI18n();
const selectedTab = ref('player');
</script>
