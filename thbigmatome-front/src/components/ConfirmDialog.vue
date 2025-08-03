<template>
  <v-dialog v-model="dialog" max-width="400" persistent>
    <v-card>
      <v-card-title class="text-h5">{{ title }}</v-card-title>
      <v-card-text v-if="message" class="confirm-dialog-message">{{ message }}</v-card-text>
      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn variant="text" @click="cancel">
          {{ t('actions.cancel') }}
        </v-btn>
        <v-btn :color="color" variant="flat" @click="confirm">
          {{ t('actions.ok') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script lang="ts" setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

const dialog = ref(false);
const title = ref('');
const message = ref<string | null>(null);
const color = ref('primary');

let resolvePromise: (value: boolean) => void;

const open = (newTitle: string, newMessage?: string, options?: { color?: string }) => {
  title.value = newTitle;
  message.value = newMessage ?? null;
  color.value = options?.color || 'primary';
  dialog.value = true;
  return new Promise<boolean>((resolve) => {
    resolvePromise = resolve;
  });
};

const confirm = () => {
  resolvePromise(true);
  dialog.value = false;
};

const cancel = () => {
  resolvePromise(false);
  dialog.value = false;
};

defineExpose({
  open,
});
</script>

<style scoped>
.confirm-dialog-message {
  white-space: pre-line;
}
</style>