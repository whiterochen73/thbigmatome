<template>
  <div>
    <MasterPanel :title="title" :icon="icon" :count="items.length">
      <template v-if="!readonly" #actions>
        <MasterAddButton :label="t(`${i18nKey}.add`)" @click="openNewDialog" />
      </template>
      <v-alert
        v-if="readonly"
        type="info"
        color="state-info"
        variant="flat"
        density="compact"
        class="ma-3"
      >
        {{ t('settings.managedByConfigFile') }}
      </v-alert>
      <v-data-table
        :headers="tableHeaders"
        :items="items"
        :loading="loading"
        :no-data-text="t(`${i18nKey}.notifications.noData`, t('teamList.noData'))"
        density="compact"
        mobile-breakpoint="sm"
      >
        <!-- eslint-disable-next-line vue/valid-v-slot -->
        <template v-if="hasDescriptionColumn" #item.description="{ item }">
          <v-tooltip :text="item.description ?? ''" location="top">
            <template #activator="{ props: activatorProps }">
              <span
                v-bind="activatorProps"
                class="d-inline-block text-truncate"
                :style="{ maxWidth: `min(${descriptionMaxWidth}, 28vw)` }"
                >{{ item.description }}</span
              >
            </template>
          </v-tooltip>
        </template>

        <!-- eslint-disable-next-line vue/valid-v-slot -->
        <template v-for="(_, name) in $slots" v-slot:[name]="slotProps">
          <slot :name="name" v-bind="slotProps"></slot>
        </template>

        <!-- eslint-disable-next-line vue/valid-v-slot -->
        <template v-if="!readonly" v-slot:item.actions="{ item }">
          <RowIconButton
            icon="mdi-pencil"
            :label="t('settings.rowActions.edit', { name: item.name })"
            @click="openEditDialog(item as T)"
          />
          <RowIconButton
            icon="mdi-delete-outline"
            danger
            :label="t('settings.rowActions.delete', { name: item.name })"
            @click="confirmDelete(item as T)"
          />
        </template>
      </v-data-table>
    </MasterPanel>

    <component
      :is="dialogComponent"
      v-model="isDialogVisible"
      :item="editingItem"
      @save="handleSave"
    />

    <ConfirmDialog ref="confirmDialog" />
  </div>
</template>

<script
  setup
  lang="ts"
  generic="T extends { id: number; name: string; description?: string | null }"
>
import { ref, onMounted, computed, type Component } from 'vue'
import { useI18n } from 'vue-i18n'
import { useSnackbar } from '@/composables/useSnackbar'
import axios from '@/plugins/axios'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import MasterPanel from '@/components/settings/MasterPanel.vue'
import MasterAddButton from '@/components/settings/MasterAddButton.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'

const props = withDefaults(
  defineProps<{
    title: string
    icon?: string
    endpoint: string
    i18nKey: string
    dialogComponent: Component
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    additionalHeaders?: any[]
    hasDescriptionColumn?: boolean
    descriptionMaxWidth?: string
    readonly?: boolean
  }>(),
  {
    icon: 'mdi-tag-outline',
    descriptionMaxWidth: '250px',
    hasDescriptionColumn: true,
    readonly: false,
  },
)

const { t } = useI18n()
const { showSnackbar } = useSnackbar()
const confirmDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null)

const loading = ref(false)
const items = ref<T[]>([])
const isDialogVisible = ref(false)
const editingItem = ref<T | null>(null)

const tableHeaders = computed(() => {
  const headers = []
  headers.push({
    title: t(`${props.i18nKey}.headers.name`),
    key: 'name',
    sortable: true,
    minWidth: '8em',
  })

  if (props.additionalHeaders) {
    headers.push(...props.additionalHeaders)
  }

  if (props.hasDescriptionColumn) {
    headers.push({
      title: t(`${props.i18nKey}.headers.description`),
      key: 'description',
      sortable: false,
    })
  }

  if (!props.readonly) {
    headers.push({
      title: t(`${props.i18nKey}.headers.actions`),
      key: 'actions',
      sortable: false,
      align: 'end' as const,
    })
  }

  return headers
})

const loadItems = async () => {
  loading.value = true
  try {
    const response = await axios.get<T[]>(props.endpoint)
    items.value = response.data
  } catch {
    showSnackbar(t(`${props.i18nKey}.notifications.fetchFailed`), 'error')
  } finally {
    loading.value = false
  }
}

onMounted(loadItems)

const openNewDialog = () => {
  editingItem.value = null
  isDialogVisible.value = true
}

const openEditDialog = (item: T) => {
  editingItem.value = { ...item }
  isDialogVisible.value = true
}

const handleSave = () => {
  isDialogVisible.value = false
  loadItems()
}

const confirmDelete = async (item: T) => {
  if (!confirmDialog.value) return
  const isConfirmed = await confirmDialog.value.open(
    t(`${props.i18nKey}.deleteConfirmTitle`),
    t(`${props.i18nKey}.deleteConfirmMessage`),
    { destructive: true },
  )

  if (isConfirmed) {
    deleteItem(item.id)
  }
}

const deleteItem = async (id: number) => {
  try {
    await axios.delete(`${props.endpoint}/${id}`)
    showSnackbar(t(`${props.i18nKey}.notifications.deleteSuccess`), 'success')
    await loadItems()
  } catch {
    showSnackbar(t(`${props.i18nKey}.notifications.deleteFailed`), 'error')
  }
}
</script>
