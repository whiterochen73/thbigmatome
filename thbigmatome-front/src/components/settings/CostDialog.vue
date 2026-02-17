<template>
  <v-dialog v-model="dialog" max-width="500px">
    <v-card>
      <v-card-title>
        <span class="text-h5">{{ isNew ? t('settings.cost.dialog.title.add') : t('settings.cost.dialog.title.edit') }}</span>
      </v-card-title>

      <v-card-text>
        <v-container>
          <v-row>
            <v-col cols="12">
              <v-text-field
                v-model="editedCost.name"
                :label="t('settings.cost.dialog.form.name')"
                :rules="[rules.required]"
                required
              ></v-text-field>
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field
                v-model="editedCost.start_date"
                :label="t('settings.cost.dialog.form.start_date')"
                type="date"
                :rules="[rules.required]"
                required
              ></v-text-field>
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field
                v-model="editedCost.end_date"
                :label="t('settings.cost.dialog.form.end_date')"
                type="date"
              ></v-text-field>
            </v-col>
          </v-row>
        </v-container>
      </v-card-text>

      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn color="blue-darken-1" variant="text" @click="cancel">
          {{ t('actions.cancel') }}
        </v-btn>
        <v-btn color="blue-darken-1" variant="text" @click="save" :disabled="!isFormValid">
          {{ t('actions.save') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

interface Props {
  modelValue: boolean;
  cost: { name: string; start_date: string | null; end_date: string | null } | null;
}

const props = defineProps<Props>();
const emit = defineEmits(['update:modelValue', 'save']);

const dialog = computed({
  get: () => props.modelValue,
  set: (value) => emit('update:modelValue', value),
});

const isNew = computed(() => !props.cost);

const editedCost = ref({
  name: props.cost?.name || '',
  start_date: props.cost?.start_date || '',
  end_date: props.cost?.end_date || '',
});

watch(() => props.cost, (newCost) => {
  editedCost.value = {
    name: newCost?.name || '',
    start_date: newCost?.start_date || '',
    end_date: newCost?.end_date || '',
  };
});

const rules = {
  required: (value: string) => !!value || t('validation.required'),
};

const isFormValid = computed(() => !!editedCost.value.name && !!editedCost.value.start_date);
const cancel = () => emit('update:modelValue', false);
const save = () => emit('save', editedCost.value);
</script>