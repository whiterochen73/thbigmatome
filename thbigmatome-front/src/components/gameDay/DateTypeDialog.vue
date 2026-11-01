<template>
  <v-dialog
    :model-value="modelValue"
    max-width="420px"
    scrollable
    @update:model-value="emit('update:modelValue', $event)"
  >
    <v-card data-testid="date-type-dialog">
      <v-card-title class="text-h6">{{ t('gameDay.dateType.label') }}</v-card-title>
      <v-card-text class="pt-0">
        <v-radio-group
          v-model="selected"
          hide-details
          density="comfortable"
          :aria-label="t('gameDay.dateType.label')"
        >
          <v-radio
            v-for="item in items"
            :key="item.value"
            :value="item.value"
            color="link"
            :data-testid="`date-type-option-${item.value}`"
          >
            <template #label>
              <v-chip
                size="small"
                variant="flat"
                :color="item.color"
                :prepend-icon="item.icon"
                :class="{ 'text-decoration-line-through': item.cancelled }"
                >{{ item.title }}</v-chip
              >
              <v-icon
                v-if="item.value === current"
                class="ml-2 on-surface-variant"
                size="20"
                :aria-label="t('gameDay.dateType.current')"
                role="img"
                data-testid="date-type-current"
                >mdi-check</v-icon
              >
            </template>
          </v-radio>
        </v-radio-group>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn
          variant="text"
          data-testid="date-type-cancel"
          @click="emit('update:modelValue', false)"
        >
          {{ t('actions.cancel') }}
        </v-btn>
        <v-btn
          color="action"
          variant="flat"
          :disabled="selected === current"
          data-testid="date-type-confirm"
          @click="onConfirm"
        >
          {{ t('gameDay.dateType.confirm') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'

// 日付種類の変更ダイアログ。種類を色・アイコンつきで並べ、今の種類に印（チェック）を付ける。
// 選んで「変更」で confirm を返す（保存は親が行う）。キャンセル・外側のクリック・Esc は何もしない
interface DateTypeItem {
  value: string
  title: string
  color: string
  icon: string
  cancelled: boolean
}

const props = defineProps<{
  modelValue: boolean
  current: string
  items: DateTypeItem[]
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  confirm: [value: string]
}>()

const { t } = useI18n()
const selected = ref(props.current)

// 開くたびに今の種類から始める（前回の選びかけを引きずらない）
watch(
  () => props.modelValue,
  (open) => {
    if (open) selected.value = props.current
  },
)

const onConfirm = () => {
  if (selected.value === props.current) return
  emit('update:modelValue', false)
  emit('confirm', selected.value)
}
</script>
