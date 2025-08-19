<template>
  <div>
    <v-table density="compact">
      <thead>
        <tr>
          <th class="text-left">{{ t('gameResult.team') }}</th>
          <th v-for="(_, index) in localScoreboard.away" :key="index" class="text-center">{{ index + 1 }}</th>
          <th class="text-center">{{ t('gameResult.total') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>{{ awayTeamName }}</td>
          <td v-for="(_, index) in localScoreboard.away" :key="index">
            <v-text-field
              type="number"
              v-model.number="localScoreboard.away[index]"
              density="compact"
              hide-details
              single-line
              @update:model-value="updateScoreboard"
            ></v-text-field>
          </td>
          <td class="text-center">{{ awayTeamScore }}</td>
        </tr>
        <tr>
          <td>{{ homeTeamName }}</td>
          <td v-for="(_, index) in localScoreboard.away" :key="index">
            <v-text-field
              v-if="index < localScoreboard.home.length"
              type="number"
              v-model.number="localScoreboard.home[index]"
              density="compact"
              hide-details
              single-line
              @update:model-value="updateScoreboard"
            ></v-text-field>
          </td>
          <td class="text-center">{{ homeTeamScore }}</td>
        </tr>
      </tbody>
    </v-table>
    <v-btn @click="addInning" class="mt-2">{{ t('gameResult.addInning') }}</v-btn>
    <v-btn @click="removeInning" class="mt-2 ml-2">{{ t('gameResult.removeInning') }}</v-btn>
    <v-checkbox
      :model-value="isWalkOff"
      :label="t('gameResult.noBottomInning')"
      @update:modelValue="onWalkoffChange"
      class="mt-2 d-inline-flex"
    ></v-checkbox>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import type { Scoreboard } from '@/types/scoreboard';

const props = defineProps<{
  modelValue: Scoreboard;
  homeTeamName: string;
  awayTeamName: string;
}>();

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const localScoreboard = ref<Scoreboard>(JSON.parse(JSON.stringify(props.modelValue)));

watch(() => props.modelValue, (newValue) => {
  localScoreboard.value = JSON.parse(JSON.stringify(newValue));
}, { deep: true });

const homeTeamScore = computed(() => {
  if (!localScoreboard.value?.home) return 0;
  return localScoreboard.value.home.reduce((acc: number, val) => acc + (Number(val) || 0), 0);
});

const awayTeamScore = computed(() => {
  if (!localScoreboard.value?.away) return 0;
  return localScoreboard.value.away.reduce((acc: number, val) => acc + (Number(val) || 0), 0);
});

const isWalkOff = computed(() => {
  return !!(localScoreboard.value && localScoreboard.value.home.length < localScoreboard.value.away.length);
});

const updateScoreboard = () => {
  emit('update:modelValue', localScoreboard.value);
};

const addInning = () => {
  const awayInnings = localScoreboard.value.away.length;
  while (localScoreboard.value.home.length < awayInnings) {
    localScoreboard.value.home.push(null);
  }
  localScoreboard.value.away.push(null);
  localScoreboard.value.home.push(null);
  updateScoreboard();
};

const removeInning = () => {
  if (localScoreboard.value.away.length > 1) {
    const wasWalkOff = localScoreboard.value.home.length < localScoreboard.value.away.length;
    localScoreboard.value.away.pop();
    if (!wasWalkOff) {
      localScoreboard.value.home.pop();
    }
    updateScoreboard();
  }
};

const onWalkoffChange = (isChecked: boolean | null) => {
  const homeInnings = localScoreboard.value.home.length;
  const awayInnings = localScoreboard.value.away.length;

  if (isChecked) {
    if (homeInnings === awayInnings && homeInnings > 0) {
      localScoreboard.value.home.pop();
    }
  } else {
    if (homeInnings < awayInnings) {
      localScoreboard.value.home.push(null);
    }
  }
  updateScoreboard();
};
</script>