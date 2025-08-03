<template>
  <v-dialog
    :model-value="modelValue"
    @update:model-value="(value) => emit('update:modelValue', value)"
    max-width="900px"
    persistent
  >
    <v-card>
      <v-card-title>
        <span class="text-h5">{{ title }}</span>
      </v-card-title>

      <v-card-text>
        <PlayerIdentityForm v-model="editableItem"></PlayerIdentityForm>

        <FielderAbilityForm v-model="editableItem"></FielderAbilityForm>

        <DefenseAbilityForm v-model="editableItem"></DefenseAbilityForm>

        <v-row dense>
          <v-col>
            <v-checkbox
              v-model="editableItem.is_pitcher"
              :label="t('playerDialog.form.is_pitcher')"
              density="compact"
            ></v-checkbox>
          </v-col>
        </v-row>

        <PitchingAbilityForm v-if="editableItem.is_pitcher" v-model="editableItem"></PitchingAbilityForm>
      </v-card-text>

      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn color="blue-darken-1" variant="text" @click="closeDialog">
          {{ t('actions.cancel') }}
        </v-btn>
        <v-btn color="blue-darken-1" variant="text" @click="saveItem" :disabled="!isFormValid">
          {{ t('actions.save') }}
        </v-btn>
      </v-card-actions>
      <v-divider></v-divider>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import axios from '@/plugins/axios'
import { isAxiosError } from 'axios'
import { useSnackbar } from '@/composables/useSnackbar'
import type { PlayerPayload } from '@/types/playerPayload'
import PlayerIdentityForm from './PlayerIdentityForm.vue'
import PitchingAbilityForm from './PitchingAbilityForm.vue'
import FielderAbilityForm from './FielderAbilityForm.vue'
import DefenseAbilityForm from './DefenseAbilityForm.vue'

interface Player extends PlayerPayload {
  id: number;
  batting_skill_ids: number[];
  player_type_ids: number[];
  biorhythm_ids: number[];
}

const props = defineProps<{
  modelValue: boolean;
  item: Player | null | undefined;
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'save'): void;
}>()

const { t } = useI18n()
const { showSnackbar } = useSnackbar()

const defaultItem: PlayerPayload = {
  name: '', number: null, short_name: null, position: null, throwing_hand: null,
  batting_style_id: null, batting_skill_ids: [], player_type_ids: [], biorhythm_ids: [],
  batting_hand: null, bunt: 1, steal_start: 1, steal_end: 1, speed: 1, injury_rate: 1,
  defense_p: null, defense_c: null, throwing_c: null, defense_1b: null,
  defense_2b: null, defense_3b: null, defense_ss: null, defense_of: null,
  throwing_of: null, defense_lf: null, throwing_lf: null, defense_cf: null,
  throwing_cf: null, defense_rf: null, throwing_rf: null, is_pitcher: false,
  is_relief_only: false, starter_stamina: null, relief_stamina: null,
  pitching_style_id: null, pinch_pitching_style_id: null, pitching_skill_ids: [],
  catcher_ids: [], partner_pitcher_ids: [],
  special_defense_c: null, special_throwing_c: null,
}

const editableItem = ref<PlayerPayload>({ ...defaultItem })

watch(() => props.modelValue, (isOpen) => {
  if (isOpen && props.item?.id) {
    editableItem.value = { ...props.item }
  } else {
    editableItem.value = { ...defaultItem }
  }
})

const title = computed(() => (props.item ? t('playerDialog.title.edit') : t('playerDialog.title.add')))

const isFormValid = computed(() => {
  const item = editableItem.value;
  return !!item.name &&
         item.bunt != null &&
         item.steal_start != null &&
         item.steal_end != null &&
         item.speed != null &&
         item.injury_rate != null;
})

watch(() => editableItem.value.position, (newPosition) => {
  if (newPosition && newPosition == 'pitcher') {
    editableItem.value.is_pitcher = true
  }
})

const closeDialog = () => {
  emit('update:modelValue', false)
}

const saveItem = async () => {
  if (!isFormValid.value) return
  try {
    const payload = { player: editableItem.value }
    props.item?.id
      ? await axios.put(`/players/${props.item.id}`, payload)
      : await axios.post('/players', payload)

    showSnackbar(props.item?.id ? t('playerDialog.notifications.updateSuccess') : t('playerDialog.notifications.addSuccess'), 'success')
    emit('save')
    closeDialog()
  } catch (error) {
    const message = isAxiosError(error) && Array.isArray(error.response?.data?.errors)
      ? t('playerDialog.notifications.saveFailedWithErrors', { errors: (error.response?.data?.errors as string[]).join('\n') })
      : t('playerDialog.notifications.saveFailed')
    showSnackbar(message, 'error')
  }
}

</script>