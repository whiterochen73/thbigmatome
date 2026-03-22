<template>
  <v-menu
    v-model="menuOpen"
    open-on-hover
    :close-on-content-click="false"
    :close-delay="200"
    :open-delay="400"
    location="bottom start"
    :offset="4"
  >
    <template #activator="{ props: activatorProps }">
      <span
        v-bind="activatorProps"
        class="player-name-link"
        @mouseenter="onHover"
        @click="onNameClick"
        >{{ playerName
        }}<v-icon size="x-small" class="ml-1">mdi-card-account-details-outline</v-icon></span
      >
    </template>
    <v-card :width="popoverWidth" elevation="4">
      <template v-if="loadingCard">
        <div class="d-flex justify-center pa-4">
          <v-progress-circular indeterminate size="24" color="primary" />
        </div>
      </template>
      <template v-else-if="showBoth">
        <template v-if="bothCardsData.length > 0">
          <div class="d-flex">
            <div v-for="card in bothCardsData" :key="card.label" style="width: 280px">
              <div class="text-caption text-center pt-1 font-weight-bold text-medium-emphasis">
                {{ card.label }}
              </div>
              <v-img v-if="card.imageUrl" :src="card.imageUrl" width="280" cover />
              <div v-else class="pa-4 text-center">
                <div class="text-caption text-grey mb-1">画像なし</div>
                <div class="text-body-2">{{ playerName }}</div>
              </div>
            </div>
          </div>
        </template>
        <template v-else>
          <div class="pa-4 text-center">
            <div class="text-caption text-grey mb-1">画像なし</div>
            <div class="text-body-2">{{ playerName }}</div>
          </div>
        </template>
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
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'

const props = defineProps<{
  playerId: number
  playerName: string
  imageUrl?: string
  cardId?: number
  cardType?: 'pitcher' | 'batter'
  showBoth?: boolean
  costType?:
    | 'normal_cost'
    | 'pitcher_only_cost'
    | 'relief_only_cost'
    | 'fielder_only_cost'
    | 'two_way_cost'
}>()

interface CardInfo {
  label: '投手' | '野手'
  imageUrl: string | null
  cardId: number | null
}

const router = useRouter()
const menuOpen = ref(false)
const loadingCard = ref(false)
const resolvedImageUrl = ref<string | null>(props.imageUrl ?? null)
const resolvedCardId = ref<number | null>(props.cardId ?? null)
const fetchDone = ref(!!props.imageUrl)
const bothCardsData = ref<CardInfo[]>([])
const fetchDoneBoth = ref(false)

// Module-level caches shared across all instances
const cache = new Map<string, { cardId: number | null; imageUrl: string | null }>()
const cacheBoth = new Map<number, CardInfo[]>()

const resolvedCardType = computed(() => {
  if (props.cardType) return props.cardType
  if (props.showBoth) return undefined
  switch (props.costType) {
    case 'pitcher_only_cost':
    case 'relief_only_cost':
      return 'pitcher'
    case 'fielder_only_cost':
      return 'batter'
    case 'two_way_cost':
      return 'batter' // showBoth=falseの場合は野手カードをデフォルト
    default:
      return undefined
  }
})

const popoverWidth = computed(() => {
  if (!props.showBoth) return 280
  if (!fetchDoneBoth.value) return 280
  return bothCardsData.value.length > 1 ? 560 : 280
})

async function fetchBothCards() {
  if (fetchDoneBoth.value) return

  const cached = cacheBoth.get(props.playerId)
  if (cached) {
    bothCardsData.value = cached
    fetchDoneBoth.value = true
    return
  }

  loadingCard.value = true
  try {
    const [pitcherRes, batterRes] = await Promise.all([
      axios.get('/player_cards', {
        params: { player_id: props.playerId, card_type: 'pitcher', per_page: 1 },
      }),
      axios.get('/player_cards', {
        params: { player_id: props.playerId, card_type: 'batter', per_page: 1 },
      }),
    ])
    const result: CardInfo[] = []
    const pitcherCard = pitcherRes.data.player_cards?.[0] ?? null
    if (pitcherCard)
      result.push({
        label: '投手',
        imageUrl: pitcherCard.image_url ?? null,
        cardId: pitcherCard.id ?? null,
      })
    const batterCard = batterRes.data.player_cards?.[0] ?? null
    if (batterCard)
      result.push({
        label: '野手',
        imageUrl: batterCard.image_url ?? null,
        cardId: batterCard.id ?? null,
      })
    cacheBoth.set(props.playerId, result)
    bothCardsData.value = result
  } catch {
    cacheBoth.set(props.playerId, [])
    bothCardsData.value = []
  } finally {
    loadingCard.value = false
    fetchDoneBoth.value = true
  }
}

async function fetchCardData() {
  if (props.showBoth) {
    return fetchBothCards()
  }
  if (fetchDone.value) return

  const cardTypeToUse = resolvedCardType.value
  const cacheKey = `${props.playerId}_${cardTypeToUse ?? 'any'}`
  const cached = cache.get(cacheKey)
  if (cached) {
    resolvedImageUrl.value = cached.imageUrl
    resolvedCardId.value = cached.cardId
    fetchDone.value = true
    return
  }

  loadingCard.value = true
  try {
    const params: Record<string, unknown> = { player_id: props.playerId, per_page: 1 }
    if (cardTypeToUse) params.card_type = cardTypeToUse
    const res = await axios.get('/player_cards', { params })
    let cards: Array<{ id: number; image_url: string | null }> = res.data.player_cards ?? []

    // Fallback: card_type指定で結果0件の場合、card_type無しで再取得
    if (cards.length === 0 && cardTypeToUse) {
      const fallbackRes = await axios.get('/player_cards', {
        params: { player_id: props.playerId, per_page: 1 },
      })
      cards = fallbackRes.data.player_cards ?? []
    }

    const card = cards[0] ?? null
    const result = { cardId: card?.id ?? null, imageUrl: card?.image_url ?? null }
    cache.set(cacheKey, result)
    resolvedImageUrl.value = result.imageUrl
    resolvedCardId.value = result.cardId
  } catch {
    cache.set(cacheKey, { cardId: null, imageUrl: null })
  } finally {
    loadingCard.value = false
    fetchDone.value = true
  }
}

function onHover() {
  fetchCardData()
}

function navigateToCard() {
  if (props.showBoth) {
    const firstCard = bothCardsData.value[0]
    if (firstCard?.cardId) {
      router.push({ name: 'PlayerCardDetail', params: { id: firstCard.cardId } })
    }
  } else if (resolvedCardId.value) {
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
  text-decoration: underline;
}
</style>
