<template>
  <div>
    <v-row dense>
      <v-col cols="12" sm="3">
        <v-text-field
          v-model="editableItem.number"
          :label="t('playerDialog.form.number')"
          maxlength="4"
          density="compact"
          clearable
          autofocus
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="5">
        <v-text-field
          v-model="editableItem.name"
          :label="t('playerDialog.form.name')"
          :rules="[rules.required]"
          required
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="4">
        <v-text-field
          v-model="editableItem.short_name"
          :label="t('playerDialog.form.short_name')"
          density="compact"
        ></v-text-field>
      </v-col>
    </v-row>
    <v-row dense>
      <v-col cols="12" sm="3">
        <v-select
          v-model="editableItem.position"
          :items="positionOptions"
          :label="t('playerDialog.form.position')"
          item-title="title"
          item-value="value"
          density="compact"
        >
          <template #item="{ props, item }">
            <v-list-item v-bind="props" :title="item.raw.japanese" />
          </template>
          <template #selection="{ item }">
            {{ item.raw.japanese }}
          </template>
        </v-select>
      </v-col>
      <v-col cols="12" sm="2">
        <v-select
          v-model="editableItem.throwing_hand"
          :items="throwingHandOptions"
          :label="t('playerDialog.form.throwing_hand')"
          item-title="title"
          item-value="value"
          density="compact"
        >
          <template #item="{ props, item }">
            <v-list-item v-bind="props" :title="item.raw.japanese" />
          </template>
          <template #selection="{ item }">
            {{ item.raw.japanese }}
          </template>
        </v-select>
      </v-col>
      <v-col cols="12" sm="2">
        <v-select
          v-model="editableItem.batting_hand"
          :items="battingHandOptions"
          :label="t('playerDialog.form.batting_hand')"
          item-title="title"
          item-value="value"
          density="compact"
        >
          <template #item="{ props, item }">
            <v-list-item v-bind="props" :title="item.raw.japanese" />
          </template>
          <template #selection="{ item }">
            {{ item.raw.japanese }}
          </template>
        </v-select>
      </v-col>
      <v-col cols="12" sm="5">
        <v-select
          v-model="editableItem.player_type_ids"
          :items="playerTypes"
          :label="t('playerDialog.form.player_types')"
          item-title="name"
          item-value="id"
          multiple
          density="compact"
          chips
          clearable
        ></v-select>
      </v-col>
    </v-row>

  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import type { PlayerType } from '@/types/playerType';
import type { PlayerDetail } from '@/types/playerDetail';
const { showSnackbar } = useSnackbar()

const { t } = useI18n();

const editableItem = defineModel<PlayerDetail>({
  type: Object,
  required: true,
});

const positionOptions = computed(() => [
  { value: 'pitcher', title: 'pitcher', japanese: t('playerDialog.positions.pitcher') },
  { value: 'catcher', title: 'catcher', japanese: t('playerDialog.positions.catcher') },
  { value: 'infielder', title: 'infielder', japanese: t('playerDialog.positions.infielder') },
  { value: 'outfielder', title: 'outfielder', japanese: t('playerDialog.positions.outfielder') },
]);

const throwingHandOptions = computed(() => [
  { value: 'right_throw', title: 'right_throw', japanese: t('playerDialog.throwing_hands.right_throw') },
  { value: 'left_throw', title: 'left_throw', japanese: t('playerDialog.throwing_hands.left_throw') },
]);

const battingHandOptions = computed(() => [
  { value: 'right_bat', title: 'right_bat', japanese: t('playerDialog.batting_hands.right_bat') },
  { value: 'left_bat', title: 'left_bat', japanese: t('playerDialog.batting_hands.left_bat') },
  { value: 'switch_hitter', title: 'switch_hitter', japanese: t('playerDialog.batting_hands.switch_hitter') },
]);

const playerTypes = ref<PlayerType[]>([])

const rules = {
  required: (value: string | number) => (value !== null && value !== '') || t('validation.required')
};

const fetchPlayerTypes = async () => {
  try {
    const response = await axios.get<PlayerType[]>('/player-types')
    playerTypes.value = response.data
  } catch (error) {
    showSnackbar(t('playerDialog.notifications.fetchPlayerTypesFailed'), 'error')
  }
}

onMounted(() => {
  fetchPlayerTypes()
})
</script>