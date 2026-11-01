<template>
  <PageLayout>
    <template #tabs>
      <v-tabs v-model="selectedTab" color="link" slider-color="link">
        <v-tab value="player">
          <v-icon start>mdi-account-cog</v-icon>
          {{ $t('settings.tabs.player') }}
        </v-tab>
        <v-tab value="squad">
          <v-icon start>mdi-calendar-clock</v-icon>
          {{ $t('settings.tabs.squad') }}
        </v-tab>
        <v-tab value="account">
          <v-icon start>mdi-lock-reset</v-icon>
          {{ $t('settings.tabs.account') }}
        </v-tab>
      </v-tabs>
    </template>

    <v-tabs-window v-model="selectedTab">
      <v-tabs-window-item value="player">
        <div class="settings-stack">
          <div class="settings-columns">
            <section class="settings-group" data-testid="settings-group-pitcher">
              <h2 class="settings-group__heading">
                <v-chip color="tag-pitcher" variant="flat" prepend-icon="mdi-baseball">{{
                  $t('settings.groups.pitcher')
                }}</v-chip>
              </h2>
              <PitchingStyleSettings />
              <PitchingSkillSettings />
            </section>
            <section class="settings-group" data-testid="settings-group-batter">
              <h2 class="settings-group__heading">
                <v-chip color="tag-fielder" variant="flat" prepend-icon="mdi-baseball-bat">{{
                  $t('settings.groups.batter')
                }}</v-chip>
              </h2>
              <BattingStyleSettings />
              <BattingSkillSettings />
            </section>
          </div>
          <section class="settings-group" data-testid="settings-group-common">
            <h2 class="settings-group__heading">
              <v-chip color="state-neutral" variant="flat" prepend-icon="mdi-tune-variant">{{
                $t('settings.groups.common')
              }}</v-chip>
            </h2>
            <PlayerTypeSettings />
            <BiorhythmSettings />
          </section>
        </div>
      </v-tabs-window-item>
      <v-tabs-window-item value="squad">
        <div class="settings-stack">
          <CostSettings />
          <ScheduleSettings />
        </div>
      </v-tabs-window-item>
      <v-tabs-window-item value="account">
        <div class="settings-narrow">
          <PasswordChangeForm />
        </div>
      </v-tabs-window-item>
    </v-tabs-window>
  </PageLayout>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRoute } from 'vue-router'

defineOptions({ name: 'SettingsView' })
import PageLayout from '@/components/shared/PageLayout.vue'
import PitchingStyleSettings from '@/components/settings/PitchingStyleSettings.vue'
import PitchingSkillSettings from '@/components/settings/PitchingSkillSettings.vue'
import BattingStyleSettings from '@/components/settings/BattingStyleSettings.vue'
import BattingSkillSettings from '@/components/settings/BattingSkillSettings.vue'
import PlayerTypeSettings from '@/components/settings/PlayerTypeSettings.vue'
import BiorhythmSettings from '@/components/settings/BiorhythmSettings.vue'
import CostSettings from '@/components/settings/CostSettings.vue'
import ScheduleSettings from '@/components/settings/ScheduleSettings.vue'
import PasswordChangeForm from '@/components/settings/PasswordChangeForm.vue'

// 画面タイトル「設定」はヘッダーバー（route.meta.title）が出す
const route = useRoute()
const selectedTab = ref((route.query.tab as string) || 'player')
</script>

<style scoped>
.settings-stack {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 16px;
}
.settings-columns {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
  align-items: start;
}
.settings-group {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 8px;
  min-width: 0;
}
.settings-group__heading {
  margin: 0;
  font-family: inherit;
  font-size: 0.8125rem;
  font-weight: 700;
}
.settings-narrow {
  max-width: 720px;
}

@media (max-width: 959.98px) {
  .settings-columns {
    grid-template-columns: minmax(0, 1fr);
  }
}
</style>
