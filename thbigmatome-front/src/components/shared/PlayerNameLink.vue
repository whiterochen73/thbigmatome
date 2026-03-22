<template>
  <v-menu
    v-model="menuOpen"
    open-on-hover
    :close-on-content-click="false"
    :close-delay="200"
    :open-delay="0"
    location="bottom start"
    :offset="4"
  >
    <template #activator="{ props: activatorProps }">
      <span
        v-bind="activatorProps"
        class="player-name-link"
        @mouseenter="onHover"
        @click="onNameClick"
        >{{ playerName }}</span
      >
    </template>
    <v-card width="280" elevation="4">
      <template v-if="loadingCard">
        <div class="d-flex justify-center pa-4">
          <v-progress-circular indeterminate size="24" color="primary" />
        </div>
      </template>
      <template v-else-if="resolvedImageUrl">
        <v-img :src="resolvedImageUrl" width="280" cover />
        <div class="text-caption text-center pa-1 text-medium-emphasis">{{ playerName }}</div>
      </template>
      <template v-else>
        <div class="pa-4 text-center">
          <div class="text-caption text-grey mb-1">画像なし</div>
          <div class="text-body-2">{{ playerName }}</div>
        </div>
      </template>
    </v-card>
  </v-menu>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'

const props = defineProps<{
  playerId: number
  playerName: string
  imageUrl?: string
  cardId?: number
}>()

const router = useRouter()
const menuOpen = ref(false)
const loadingCard = ref(false)
const resolvedImageUrl = ref<string | null>(props.imageUrl ?? null)
const resolvedCardId = ref<number | null>(props.cardId ?? null)
const fetchDone = ref(!!props.imageUrl)

// Module-level cache shared across all instances
const cache = new Map<number, { cardId: number | null; imageUrl: string | null }>()

async function fetchCardData() {
  if (fetchDone.value) return

  const cached = cache.get(props.playerId)
  if (cached) {
    resolvedImageUrl.value = cached.imageUrl
    resolvedCardId.value = cached.cardId
    fetchDone.value = true
    return
  }

  loadingCard.value = true
  try {
    const res = await axios.get('/player_cards', {
      params: { player_id: props.playerId, per_page: 1 },
    })
    const cards: Array<{ id: number; image_url: string | null }> = res.data.player_cards ?? []
    const card = cards[0] ?? null
    const result = { cardId: card?.id ?? null, imageUrl: card?.image_url ?? null }
    cache.set(props.playerId, result)
    resolvedImageUrl.value = result.imageUrl
    resolvedCardId.value = result.cardId
  } catch {
    cache.set(props.playerId, { cardId: null, imageUrl: null })
  } finally {
    loadingCard.value = false
    fetchDone.value = true
  }
}

function onHover() {
  fetchCardData()
}

function navigateToCard() {
  if (resolvedCardId.value) {
    router.push({ name: 'PlayerCardDetail', params: { id: resolvedCardId.value } })
  }
}

function onNameClick() {
  if (menuOpen.value) {
    // Desktop: already open via hover → navigate; Mobile: second tap → navigate
    navigateToCard()
  } else {
    // Mobile first tap: open the menu and fetch
    menuOpen.value = true
    fetchCardData()
  }
}
</script>

<style scoped>
.player-name-link {
  cursor: pointer;
  color: rgb(var(--v-theme-primary));
}

.player-name-link:hover {
  text-decoration: underline;
}
</style>
