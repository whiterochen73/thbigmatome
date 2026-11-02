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
      <AsyncState
        :loading="loading"
        :error="fetchFailed"
        :error-message="t(`${i18nKey}.notifications.fetchFailed`)"
        :empty="items.length === 0"
        :empty-message="t(`${i18nKey}.notifications.noData`, t('teamList.noData'))"
        @retry="loadItems"
      >
        <v-data-table
          :headers="tableHeaders"
          :items="items"
          density="compact"
          class="ui-table--rows"
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
            <div class="row-actions">
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
            </div>
          </template>
        </v-data-table>
      </AsyncState>
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
import AsyncState from '@/components/shared/AsyncState.vue'
import MasterPanel from '@/components/settings/MasterPanel.vue'
import MasterAddButton from '@/components/settings/MasterAddButton.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'
import { tableCell } from '@/components/shared/tableCells'

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

const loading = ref(true)
const fetchFailed = ref(false)
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
    cellProps: tableCell.title,
  })

  if (props.additionalHeaders) {
    // 追加の列はスマホの縦積み行で要点 1・2 に、見出し付きで置く（呼び出し側が cellProps を決めていればそれを使う）
    props.additionalHeaders.forEach((header, i) => {
      headers.push({
        cellProps: i === 0 ? tableCell.sub1Labeled : tableCell.sub2Labeled,
        ...header,
      })
    })
  }

  if (props.hasDescriptionColumn) {
    headers.push({
      title: t(`${props.i18nKey}.headers.description`),
      key: 'description',
      sortable: false,
      cellProps: tableCell.note,
    })
  }

  if (!props.readonly) {
    headers.push({
      title: t(`${props.i18nKey}.headers.actions`),
      key: 'actions',
      sortable: false,
      align: 'end' as const,
      cellProps: tableCell.act,
    })
  }

  return headers
})

const loadItems = async () => {
  loading.value = true
  fetchFailed.value = false
  try {
    const response = await axios.get<T[]>(props.endpoint)
    items.value = response.data
  } catch {
    // 取得の失敗はその場のアラート（AsyncState）で出す。スナックバーは削除の成否だけ
    fetchFailed.value = true
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
