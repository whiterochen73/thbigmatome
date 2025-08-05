<template>
  <div>
    <v-row>
      <v-col>
        <h3 class="text-subtitle-1">{{ t('playerDialog.form.defenseSectionTitle') }}</h3>
      </v-col>
    </v-row>

    <!-- 投手・捕手 -->
    <v-row  dense>
      <v-col cols="6" sm="2">
        <v-text-field
          v-model="editableItem.defense_p"
          :label="t('playerDialog.defensePositions.p')"
          :rules="[rules.defenseFormat]"
          maxlength="2"

          clearable
          :hint="t('validation.defenseFormat')"
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="6" sm="2">
        <v-text-field
          v-model="editableItem.defense_c"
          :label="t('playerDialog.defensePositions.c')"
          :rules="[rules.defenseFormat]"
          maxlength="2"
          counter
          clearable
          :hint="t('validation.defenseFormat')"
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="6" sm="2">
        <v-text-field
          v-model.number="editableItem.throwing_c"
          :label="`${t('playerDialog.defensePositions.c')} ${t('playerDialog.form.throwing')}`"
          type="number"
          :disabled="!editableItem.defense_c"
          clearable
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="6">
        <v-checkbox
          v-model="showPartnerPitchers"
          :label="t('playerDialog.form.hasPartnerPitchers')"
          density="compact"
        ></v-checkbox>
      </v-col>
    </v-row>

    <template v-if="showPartnerPitchers">
      <v-row dense>
        <v-col cols="12" sm="6">
          <PlayerSelect
            v-model="editableItem.partner_pitcher_ids"
            v-model:players="pitchers"
            :label="t('playerDialog.form.partner_pitchers')"
          ></PlayerSelect>
        </v-col>
      <v-col cols="6" sm="2">
        <v-text-field
          v-model="editableItem.special_defense_c"
          :label="t('playerDialog.defensePositions.c')"
          :rules="[rules.defenseFormat]"
          maxlength="2"
          counter
          clearable
          :hint="t('validation.defenseFormat')"
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="6" sm="2">
        <v-text-field
          v-model.number="editableItem.special_throwing_c"
          :label="`${t('playerDialog.defensePositions.c')} ${t('playerDialog.form.throwing')}`"
          type="number"
          :disabled="!editableItem.special_defense_c"
          clearable
          density="compact"
        ></v-text-field>
      </v-col>
      </v-row>
    </template>

    <!-- 内野手 -->
    <v-row dense>
      <v-col cols="6" sm="2">
        <v-text-field
          v-model="editableItem.defense_1b"
          :label="t('playerDialog.defensePositions.1b')"
          :rules="[rules.defenseFormat]"
          maxlength="2"
          counter
          clearable
          :hint="t('validation.defenseFormat')"
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="6" sm="2">
        <v-text-field
          v-model="editableItem.defense_2b"
          :label="t('playerDialog.defensePositions.2b')"
          :rules="[rules.defenseFormat]"
          maxlength="2"
          counter
          clearable
          :hint="t('validation.defenseFormat')"
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="6" sm="2">
        <v-text-field
          v-model="editableItem.defense_3b"
          :label="t('playerDialog.defensePositions.3b')"
          :rules="[rules.defenseFormat]"
          maxlength="2"
          counter
          clearable
          :hint="t('validation.defenseFormat')"
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="6" sm="2">
        <v-text-field
          v-model="editableItem.defense_ss"
          :label="t('playerDialog.defensePositions.ss')"
          :rules="[rules.defenseFormat]"
          maxlength="2"
          counter
          clearable
          :hint="t('validation.defenseFormat')"
          density="compact"
        ></v-text-field>
      </v-col>
      <!-- 外野手 -->
      <template v-if="!showIndividualOutfielders">
        <v-col cols="6" sm="2">
          <v-text-field
            v-model="editableItem.defense_of"
            :label="t('playerDialog.defensePositions.of')"
            :rules="[rules.defenseFormat]"
            maxlength="2"
            counter
            clearable
            :hint="t('validation.defenseFormat')"
            density="compact"
          ></v-text-field>
        </v-col>
        <v-col cols="6" sm="2">
          <v-select
            v-model="editableItem.throwing_of"
            :items="outfielderThrowingOptions"
            :label="`${t('playerDialog.defensePositions.of')} ${t('playerDialog.form.throwing')}`"
            :disabled="!editableItem.defense_of"
            clearable
            density="compact"
          ></v-select>
        </v-col>
      </template>
    </v-row>

    <v-row dense>
      <v-col cols="12">
        <v-checkbox
          v-model="showIndividualOutfielders"
          :label="t('playerDialog.form.setIndividualOutfielders')"
          density="compact"
        ></v-checkbox>
      </v-col>
    </v-row>

    <template v-if="showIndividualOutfielders">
      <v-row dense>
        <v-col cols="12" sm="2">
          <v-text-field
            v-model="editableItem.defense_lf"
            :label="t('playerDialog.defensePositions.lf')"
            :rules="[rules.defenseFormat]"
            maxlength="2"
            counter
            clearable
            :hint="t('validation.defenseFormat')"
            density="compact"
          ></v-text-field>
        </v-col>
        <v-col cols="12" sm="2">
          <v-select
            v-model="editableItem.throwing_lf"
            :items="outfielderThrowingOptions"
            :label="`${t('playerDialog.defensePositions.lf')} ${t('playerDialog.form.throwing')}`"
            :disabled="!editableItem.defense_lf"
            clearable
            density="compact"
          ></v-select>
        </v-col>
        <v-col cols="12" sm="2">
          <v-text-field
            v-model="editableItem.defense_cf"
            :label="t('playerDialog.defensePositions.cf')"
            :rules="[rules.defenseFormat]"
            maxlength="2"
            counter
            clearable
            :hint="t('validation.defenseFormat')"
            density="compact"
          ></v-text-field>
        </v-col>
        <v-col cols="12" sm="2">
          <v-select
            v-model="editableItem.throwing_cf"
            :items="outfielderThrowingOptions"
            :label="`${t('playerDialog.defensePositions.cf')} ${t('playerDialog.form.throwing')}`"
            :disabled="!editableItem.defense_cf"
            clearable
            density="compact"
          ></v-select>
        </v-col>
        <v-col cols="12" sm="2">
          <v-text-field
            v-model="editableItem.defense_rf"
            :label="t('playerDialog.defensePositions.rf')"
            :rules="[rules.defenseFormat]"
            maxlength="2"
            counter
            clearable
            :hint="t('validation.defenseFormat')"
            density="compact"
          ></v-text-field>
        </v-col>
        <v-col cols="12" sm="2">
          <v-select
            v-model="editableItem.throwing_rf"
            :items="outfielderThrowingOptions"
            :label="`${t('playerDialog.defensePositions.rf')} ${t('playerDialog.form.throwing')}`"
            :disabled="!editableItem.defense_rf"
            clearable
            density="compact"
          ></v-select>
        </v-col>
      </v-row>
    </template>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useSnackbar } from '@/composables/useSnackbar'
import PlayerSelect from '@/components/shared/PlayerSelect.vue';
import axios from 'axios';
import type { Player, PlayerPayload } from '@/types/player';

const editableItem = defineModel<PlayerPayload>({
  type: Object,
  required: true,
});
const emit = defineEmits(['update:defense', 'update:showIndividualOutfielders']);
const { t } = useI18n();
const { showSnackbar } = useSnackbar()

const showIndividualOutfielders = ref(false);
const showPartnerPitchers = ref(false);

const rules = {
  defenseFormat: (value: string) =>
    !value || /^[0-5][A-E|S]$/.test(value) || t('validation.validation.defenseFormat'),
};

const outfielderThrowingOptions = ['S', 'A', 'B', 'C'];

watch(() => editableItem, (newItem) => {
  if (newItem) {
    showPartnerPitchers.value = !!newItem.value.partner_pitcher_ids?.length;
    showIndividualOutfielders.value = !!(editableItem.value.defense_lf || editableItem.value.defense_cf || editableItem.value.defense_rf);
  } else {
    showIndividualOutfielders.value = false;
  }
}, { immediate: true, deep: true })


watch(showIndividualOutfielders, (isIndividual) => {
  if (!isIndividual) {
    editableItem.value.defense_lf = null;
    editableItem.value.throwing_lf = null;
    editableItem.value.defense_cf = null;
    editableItem.value.throwing_cf = null;
    editableItem.value.defense_rf = null;
    editableItem.value.throwing_rf = null;
  }
});

const pitchers = ref<Player[]>([]);
const fetchPitchers = async () => {
  try {
    const response = await axios.get<Player[]>('/players')
    pitchers.value = response.data
  } catch (error) {
    showSnackbar(t('playerDialog.notifications.fetchCatchersFailed'), 'error')
  }
}

onMounted(() => {
  fetchPitchers()
})
</script>