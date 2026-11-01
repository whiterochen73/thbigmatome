<template>
  <PageLayout class="commissioner-dashboard-page">
    <CommissionerDashboard />
  </PageLayout>
</template>

<script setup lang="ts">
import PageLayout from '@/components/shared/PageLayout.vue'
import CommissionerDashboard from '@/components/commissioner/CommissionerDashboard.vue'
</script>

<style scoped>
/* ダッシュボードのタブ（v-tabs.mb-4）の下余白は、骨格のブロック間隔（16px）に任せる */
.commissioner-dashboard-page :deep(> .v-tabs.mb-4) {
  margin-bottom: 0 !important;
}
</style>
