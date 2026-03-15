<template>
  <v-container>
    <PageHeader title="ダッシュボード" />
    <CommissionerDashboard />
  </v-container>
</template>

<script setup lang="ts">
import PageHeader from '@/components/shared/PageHeader.vue'
import CommissionerDashboard from '@/components/commissioner/CommissionerDashboard.vue'
</script>
