<template>
  <v-dialog :model-value="modelValue" @update:model-value="(value) => emit('update:modelValue', value)" max-width="500px" persistent>
    <v-card>
      <v-card-title>
        <span class="text-h5">{{ title }}</span>
      </v-card-title>

      <v-card-text>
        <v-container>
          <v-row>
            <v-col cols="12">
              <v-text-field
                v-model="editableItem.name"
                :label="t('settings.pitchingSkill.dialog.form.name')"
                :rules="[rules.required]"
                required
              ></v-text-field>
            </v-col>
            <v-col cols="12">
              <v-select
                v-model="editableItem.skill_type"
                :items="skillTypeOptions"
                :label="t('settings.pitchingSkill.dialog.form.skill_type')"
                :bg-color="skillTypeBackgroundColor"
                :rules="[rules.required]"
                required
              ></v-select>
            </v-col>
            <v-col cols="12">
              <v-textarea
                v-model="editableItem.description"
                :label="t('settings.pitchingSkill.dialog.form.description')"
                rows="3"
              ></v-textarea>
            </v-col>
          </v-row>
        </v-container>
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
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import type { PitchingSkill } from '@/types/pitchingSkill'
import axios from '@/plugins/axios'
import { isAxiosError } from 'axios'
import { useSnackbar } from '@/composables/useSnackbar'

type PitchingSkillPayload = Omit<PitchingSkill, 'id'>

const props = defineProps<{
  modelValue: boolean
  item: PitchingSkill | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'save'): void
}>()

const { t } = useI18n()
const { showSnackbar } = useSnackbar()

const defaultItem: PitchingSkillPayload = { name: '', description: null, skill_type: 'neutral' }
const editableItem = ref<PitchingSkillPayload>({ ...defaultItem })

const skillTypeOptions = computed(() => [
  { title: t('settings.pitchingSkill.skillTypes.positive'), value: 'positive' },
  { title: t('settings.pitchingSkill.skillTypes.negative'), value: 'negative' },
  { title: t('settings.pitchingSkill.skillTypes.neutral'), value: 'neutral' },
])

const skillTypeBackgroundColor = computed(() => {
  if (!editableItem.value.skill_type) return undefined
  switch (editableItem.value.skill_type) {
    case 'positive':
      return 'blue-lighten-5'
    case 'negative':
      return 'red-lighten-5'
    case 'neutral':
      return 'green-lighten-5'
    default:
      return undefined
  }
})

watch(() => props.item, (newItem) => {
  editableItem.value = newItem ? { ...newItem } : { ...defaultItem }
})

const title = computed(() => props.item ? t('settings.pitchingSkill.dialog.title.edit') : t('settings.pitchingSkill.dialog.title.add'))

const rules = {
  required: (value: string) => !!value || t('validation.required'),
}

const isFormValid = computed(() => !!editableItem.value.name && !!editableItem.value.skill_type)

const closeDialog = () => {
  emit('update:modelValue', false)
}

const saveItem = async () => {
  if (!isFormValid.value) return

  try {
    const payload = { ...editableItem.value }
    if (props.item?.id) {
      await axios.put(`/pitching-skills/${props.item.id}`, { pitching_skill: payload })
      showSnackbar(t('settings.pitchingSkill.notifications.updateSuccess'), 'success')
    } else {
      await axios.post('/pitching-skills', { pitching_skill: payload })
      showSnackbar(t('settings.pitchingSkill.notifications.addSuccess'), 'success')
    }
    emit('save')
    closeDialog()
  } catch (error) {
    if (isAxiosError(error) && Array.isArray(error.response?.data?.errors)) {
      const errorMessages = (error.response?.data?.errors as string[]).join('\n')
      showSnackbar(t('settings.pitchingSkill.notifications.saveFailedWithErrors', { errors: errorMessages }), 'error')
    } else {
      showSnackbar(t('settings.pitchingSkill.notifications.saveFailed'), 'error')
    }
  }
}
</script>