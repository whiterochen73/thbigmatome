<template>
  <v-container fluid>
    <v-row>
      <v-col cols="12">
        <h1>各種設定</h1>
        <p class="mt-4">この画面では、アプリケーション全体で利用される細かいマスターデータの設定を行います。</p>
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
  </v-container>
</template>

<script setup lang="ts">
import PitchingStyleSettings from '@/components/settings/PitchingStyleSettings.vue';
import PitchingSkillSettings from '@/components/settings/PitchingSkillSettings.vue';
import BattingStyleSettings from '@/components/settings/BattingStyleSettings.vue';
import BattingSkillSettings from '@/components/settings/BattingSkillSettings.vue';
import PlayerTypeSettings from '@/components/settings/PlayerTypeSettings.vue';
import BiorhythmSettings from '@/components/settings/BiorhythmSettings.vue';
</script>