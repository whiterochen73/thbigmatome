<template>
  <v-container>
    <v-row justify="center">
      <v-col cols="12" md="8">
        <v-card>
          <v-card-item>
            <v-card-title class="text-h5">{{ t('topMenu.welcome.title') }}</v-card-title>
            <v-card-subtitle>{{ t('topMenu.welcome.subtitle') }}</v-card-subtitle>
          </v-card-item>
          <v-card-text>
            <p>{{ t('topMenu.welcome.message') }}</p>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'

const { t } = useI18n()
</script>
