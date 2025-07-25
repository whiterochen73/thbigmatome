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
                :label="t('settings.battingSkill.dialog.form.name')"
                :rules="[rules.required]"
                required
              ></v-text-field>
            </v-col>
            <v-col cols="12">
              <v-select
                v-model="editableItem.skill_type"
                :items="skillTypeOptions"
                :label="t('settings.battingSkill.dialog.form.skill_type')"
                :bg-color="skillTypeBackgroundColor"
                :rules="[rules.required]"
                required
              ></v-select>
            </v-col>
            <v-col cols="12">
              <v-textarea
                v-model="editableItem.description"
                :label="t('settings.battingSkill.dialog.form.description')"
                rows="3"
              ></v-textarea>
            </v-col>
          </v-row>
        </v-container>
      </v-card-text>

      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn color="blue-darken-1" variant="text" @click="closeDialog">
          {{ t('teamDialog.actions.cancel') }}
        </v-btn>
        <v-btn color="blue-darken-1" variant="text" @click="saveItem" :disabled="!isFormValid">
          {{ t('teamDialog.actions.save') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import type { BattingSkill } from '@/types/battingSkill'
import axios from '@/plugins/axios'
import { isAxiosError } from 'axios'
import { useSnackbar } from '@/composables/useSnackbar'

type BattingSkillPayload = Omit<BattingSkill, 'id'>

const props = defineProps<{
  modelValue: boolean
  item: BattingSkill | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'save'): void
}>()

const { t } = useI18n()
const { showSnackbar } = useSnackbar()

const defaultItem: BattingSkillPayload = { name: '', description: null, skill_type: 'neutral' }
const editableItem = ref<BattingSkillPayload>({ ...defaultItem })

const skillTypeOptions = computed(() => [
  { title: t('settings.battingSkill.skillTypes.positive'), value: 'positive' },
  { title: t('settings.battingSkill.skillTypes.negative'), value: 'negative' },
  { title: t('settings.battingSkill.skillTypes.neutral'), value: 'neutral' },
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

const title = computed(() => props.item ? t('settings.battingSkill.dialog.title.edit') : t('settings.battingSkill.dialog.title.add'))

const rules = {
  required: (value: string) => !!value || t('managerDialog.validation.required'),
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
      await axios.put(`/batting-skills/${props.item.id}`, { batting_skill: payload })
      showSnackbar(t('settings.battingSkill.notifications.updateSuccess'), 'success')
    } else {
      await axios.post('/batting-skills', { batting_skill: payload })
      showSnackbar(t('settings.battingSkill.notifications.addSuccess'), 'success')
    }
    emit('save')
    closeDialog()
  } catch (error) {
    if (isAxiosError(error) && Array.isArray(error.response?.data?.errors)) {
      const errorMessages = (error.response?.data?.errors as string[]).join('\n')
      showSnackbar(t('settings.battingSkill.notifications.saveFailedWithErrors', { errors: errorMessages }), 'error')
    } else {
      showSnackbar(t('settings.battingSkill.notifications.saveFailed'), 'error')
    }
  }
}
</script>