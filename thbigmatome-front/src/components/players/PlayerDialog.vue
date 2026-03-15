<template>
  <v-dialog v-model="isOpen" max-width="900px" persistent>
    <v-card>
      <v-card-title>
        <span class="text-h5">{{ title }}</span>
      </v-card-title>

      <v-card-text>
        <PlayerIdentityForm v-model="editableItem"></PlayerIdentityForm>
      </v-card-text>

      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn variant="text" @click="closeDialog">
          {{ t('actions.cancel') }}
        </v-btn>
        <v-btn color="accent" variant="flat" @click="saveItem" :disabled="!isFormValid">
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
import type { PlayerDetail } from '@/types/playerDetail'
import PlayerIdentityForm from './PlayerIdentityForm.vue'

const isOpen = defineModel<boolean>({ default: false })

const props = defineProps<{
  item: PlayerDetail | null
}>()

const emit = defineEmits<{
  (e: 'save'): void
}>()

const { t } = useI18n()
const { showSnackbar } = useSnackbar()

const defaultItem: PlayerDetail = {
  id: null,
  name: '',
  number: null,
  short_name: null,
}

const editableItem = ref<PlayerDetail>({ ...defaultItem })

watch(isOpen, (value) => {
  if (value && props.item) {
    editableItem.value = props.item
  } else {
    editableItem.value = { ...defaultItem }
  }
})

const title = computed(() =>
  props.item ? t('playerDialog.title.edit') : t('playerDialog.title.add'),
)

const isFormValid = computed(() => {
  const item = editableItem.value
  return !!item.name
})

const closeDialog = () => {
  isOpen.value = false
}

const saveItem = async () => {
  if (!isFormValid.value) return
  try {
    const payload = { player: editableItem.value }
    if (props.item?.id) {
      await axios.put(`/players/${props.item.id}`, payload)
    } else {
      await axios.post('/players', payload)
    }

    showSnackbar(
      props.item?.id
        ? t('playerDialog.notifications.updateSuccess')
        : t('playerDialog.notifications.addSuccess'),
      'success',
    )
    emit('save')
    closeDialog()
  } catch (error) {
    const message =
      isAxiosError(error) && Array.isArray(error.response?.data?.errors)
        ? t('playerDialog.notifications.saveFailedWithErrors', {
            errors: (error.response?.data?.errors as string[]).join('\n'),
          })
        : t('playerDialog.notifications.saveFailed')
    showSnackbar(message, 'error')
  }
}
</script>
