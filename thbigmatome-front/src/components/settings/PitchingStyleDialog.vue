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
                :label="t('settings.pitchingStyle.dialog.form.name')"
                :rules="[rules.required]"
                required
              ></v-text-field>
            </v-col>
            <v-col cols="12">
              <v-textarea
                v-model="editableItem.description"
                :label="t('settings.pitchingStyle.dialog.form.description')"
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
import type { PitchingStyle } from '@/types/pitchingStyle'
import axios from '@/plugins/axios'
import { isAxiosError } from 'axios'
import { useSnackbar } from '@/composables/useSnackbar'

type PitchingStylePayload = Omit<PitchingStyle, 'id'>

const props = defineProps<{
  modelValue: boolean
  item: PitchingStyle | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'save'): void
}>()

const { t } = useI18n()
const { showSnackbar } = useSnackbar()

const defaultItem: PitchingStylePayload = { name: '', description: null }
const editableItem = ref<PitchingStylePayload>({ ...defaultItem })

watch(() => props.item, (newItem) => {
  editableItem.value = newItem ? { ...newItem } : { ...defaultItem }
})

const title = computed(() => props.item ? t('settings.pitchingStyle.dialog.title.edit') : t('settings.pitchingStyle.dialog.title.add'))

const rules = {
  required: (value: string) => !!value || t('managerDialog.validation.required'),
}

const isFormValid = computed(() => !!editableItem.value.name)

const closeDialog = () => {
  emit('update:modelValue', false)
}

const saveItem = async () => {
  if (!isFormValid.value) return

  try {
    const payload = { ...editableItem.value }
    if (props.item?.id) {
      await axios.put(`/pitching-styles/${props.item.id}`, { pitching_style: payload })
      showSnackbar(t('settings.pitchingStyle.notifications.updateSuccess'), 'success')
    } else {
      await axios.post('/pitching-styles', { pitching_style: payload })
      showSnackbar(t('settings.pitchingStyle.notifications.addSuccess'), 'success')
    }
    emit('save')
    closeDialog()
  } catch (error) {
    if (isAxiosError(error) && Array.isArray(error.response?.data?.errors)) {
      const errorMessages = (error.response?.data?.errors as string[]).join('\n')
      showSnackbar(t('settings.pitchingStyle.notifications.saveFailedWithErrors', { errors: errorMessages }), 'error')
    } else {
      showSnackbar(t('settings.pitchingStyle.notifications.saveFailed'), 'error')
    }
  }
}
</script>