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
                :label="t('settings.biorhythm.dialog.form.name')"
                :rules="[rules.required]"
                required
              ></v-text-field>
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model="editableItem.start_date"
                :label="t('settings.biorhythm.dialog.form.start_date')"
                placeholder="YYYY-MM-DD"
                :rules="[rules.required, rules.dateFormat]"
                required
              ></v-text-field>
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model="editableItem.end_date"
                :label="t('settings.biorhythm.dialog.form.end_date')"
                placeholder="YYYY-MM-DD"
                :rules="[rules.required, rules.dateFormat]"
                required
              ></v-text-field>
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
import type { Biorhythm } from '@/types/biorhythm'
import axios from '@/plugins/axios'
import { isAxiosError } from 'axios'
import { useSnackbar } from '@/composables/useSnackbar'

type BiorhythmPayload = Omit<Biorhythm, 'id'>

const props = defineProps<{ modelValue: boolean; item: Biorhythm | null }>()
const emit = defineEmits<{ (e: 'update:modelValue', value: boolean): void; (e: 'save'): void }>()

const { t } = useI18n()
const { showSnackbar } = useSnackbar()

const defaultItem: BiorhythmPayload = { name: '', start_date: '', end_date: '' }
const editableItem = ref<BiorhythmPayload>({ ...defaultItem })

watch(() => props.item, (newItem) => {
  editableItem.value = newItem ? { ...newItem } : { ...defaultItem }
})

const title = computed(() => props.item ? t('settings.biorhythm.dialog.title.edit') : t('settings.biorhythm.dialog.title.add'))

const rules = {
  required: (value: string) => !!value || t('validation.required'),
  dateFormat: (value: string) => /^\d{4}-\d{2}-\d{2}$/.test(value) || t('validation.dateFormat'),
}

const isFormValid = computed(() => {
  return !!editableItem.value.name && rules.dateFormat(editableItem.value.start_date) === true && rules.dateFormat(editableItem.value.end_date) === true
})

const closeDialog = () => emit('update:modelValue', false)

const saveItem = async () => {
  if (!isFormValid.value) return
  try {
    const payload = { biorhythm: { ...editableItem.value } }
    const messageKey = props.item?.id ? 'updateSuccess' : 'addSuccess'
    const request = props.item?.id ? axios.put(`/biorhythms/${props.item.id}`, payload) : axios.post('/biorhythms', payload)
    await request
    showSnackbar(t(`settings.biorhythm.notifications.${messageKey}`), 'success')
    emit('save')
    closeDialog()
  } catch (error) {
    const errorMessages = isAxiosError(error) && Array.isArray(error.response?.data?.errors) ? (error.response?.data.errors as string[]).join('\n') : ''
    showSnackbar(errorMessages ? t('settings.biorhythm.notifications.saveFailedWithErrors', { errors: errorMessages }) : t('settings.biorhythm.notifications.saveFailed'), 'error')
  }
}
</script>