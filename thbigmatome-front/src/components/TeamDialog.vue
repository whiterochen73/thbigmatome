<template>
  <v-dialog v-model="internalIsVisible" max-width="500px">
    <v-card>
      <v-card-title>
        <span class="text-h5">{{
          isNew ? t('teamDialog.title.add') : t('teamDialog.title.edit')
        }}</span>
      </v-card-title>

      <v-card-text>
        <v-container>
          <v-row>
            <v-col cols="12">
              <v-text-field
                v-model="editedTeam.name"
                :label="t('teamDialog.form.name')"
                :rules="[rules.required]"
                required
              ></v-text-field>
            </v-col>
            <v-col cols="12">
              <v-text-field
                v-model="editedTeam.short_name"
                :label="t('teamDialog.form.shortName')"
              ></v-text-field>
            </v-col>
            <v-col cols="12">
              <v-autocomplete
                :readonly="!!props.defaultManagerId"
                v-model="editedTeam.director_id"
                :items="managers"
                item-title="name"
                item-value="id"
                :label="t('teamDialog.form.director')"
              ></v-autocomplete>
            </v-col>
            <v-col cols="12">
              <v-autocomplete
                v-model="editedTeam.coach_ids"
                :items="managers"
                item-title="name"
                item-value="id"
                :label="t('teamDialog.form.coaches')"
                multiple
              ></v-autocomplete>
            </v-col>
            <v-col cols="12">
              <v-checkbox
                v-model="editedTeam.is_active"
                :label="t('teamDialog.form.isActive')"
              ></v-checkbox>
            </v-col>
          </v-row>
        </v-container>
      </v-card-text>

      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn color="blue-darken-1" variant="text" @click="close">
          {{ t('actions.cancel') }}
        </v-btn>
        <v-btn color="blue-darken-1" variant="text" @click="save" :disabled="!isFormValid">
          {{ t('actions.save') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script lang="ts" setup>
import { ref, watch, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import { type Team } from '@/types/team'
import { type Manager } from '@/types/manager'

const { t } = useI18n()
const { showSnackbar } = useSnackbar()

interface Props {
  isVisible: boolean
  team: Team | null
  defaultManagerId?: number | null
}

const props = withDefaults(defineProps<Props>(), {
  isVisible: false,
  team: null,
  defaultManagerId: null,
})

const emit = defineEmits(['update:isVisible', 'save'])

const internalIsVisible = computed({
  get: () => props.isVisible,
  set: (value) => emit('update:isVisible', value),
})

interface EditedTeam {
  name: string
  short_name: string
  is_active: boolean
  director_id?: number | null
  coach_ids?: number[]
}

const defaultTeam: EditedTeam = {
  name: '',
  short_name: '',
  is_active: true,
  director_id: null,
  coach_ids: [],
}
const editedTeam = ref<EditedTeam>({ ...defaultTeam })

const managers = ref<Manager[]>([])

const isNew = computed(() => !props.team)

const rules = {
  required: (value: string) => !!value || t('validation.required'),
}

const isFormValid = computed(() => !!editedTeam.value.name)

const fetchManagers = async () => {
  try {
    const response = await axios.get<{ data: Manager[] }>('/managers')
    managers.value = response.data.data
  } catch (error) {
    console.error('Error fetching managers:', error)
    showSnackbar(t('teamDialog.notifications.fetchManagersFailed'), 'error')
  }
}

watch(
  () => props.isVisible,
  (newVal) => {
    if (newVal) {
      if (props.team) {
        // Edit
        editedTeam.value = {
          name: props.team.name,
          short_name: props.team.short_name,
          is_active: props.team.is_active,
          director_id: props.team.director?.id,
          coach_ids: props.team.coaches?.map((c) => c.id) ?? [],
        }
      } else {
        // New
        editedTeam.value = { ...defaultTeam, director_id: props.defaultManagerId ?? null }
      }

      if (managers.value.length === 0) {
        fetchManagers()
      }
    }
  },
)

watch(
  () => props.defaultManagerId,
  (newManagerId) => {
    if (newManagerId && !props.team) {
      editedTeam.value.director_id = newManagerId
    }
  },
  { immediate: true },
)

const close = () => {
  internalIsVisible.value = false
}

const save = async () => {
  if (!isFormValid.value) return

  const teamData: EditedTeam = { ...editedTeam.value }

  try {
    if (isNew.value) {
      await axios.post('/teams', { team: teamData })
      showSnackbar(t('teamDialog.notifications.addSuccess'), 'success')
    } else {
      await axios.patch(`/teams/${props.team?.id}`, { team: teamData })
      showSnackbar(t('teamDialog.notifications.updateSuccess'), 'success')
    }
    emit('save')
    close()
  } catch (error: unknown) {
    console.error('Error saving team:', error)
    const axiosError = error as { response?: { data?: { errors?: Record<string, string[]> } } }
    if (axiosError.response?.data?.errors) {
      const errorMessages = Object.values(axiosError.response.data.errors).flat().join('\n')
      showSnackbar(
        t('teamDialog.notifications.saveFailedWithErrors', { errors: errorMessages }),
        'error',
      )
    } else {
      showSnackbar(t('teamDialog.notifications.saveFailed'), 'error')
    }
  }
}
</script>
