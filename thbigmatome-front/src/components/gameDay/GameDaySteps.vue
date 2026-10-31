<template>
  <!-- スマホ・狭い幅: 段を縦に積んで折りたたむ -->
  <div v-if="mode === 'stack'" class="game-day-stack" data-testid="game-day-stack">
    <div
      v-for="group in groups"
      :key="group.id"
      :data-testid="`step-group-${group.id}`"
      class="game-day-stack__group"
      :class="`game-day-stack__group--${group.id}`"
      role="group"
      :aria-label="t(`gameDay.phase.${group.id}`)"
    >
      <div class="game-day-phase text-caption mb-1 mt-4">
        <v-icon size="small" aria-hidden="true">{{ groupIcon(group.id) }}</v-icon>
        {{ t(`gameDay.phase.${group.id}`) }}
      </div>
      <div class="d-flex flex-column ga-2">
        <template v-for="step in group.steps" :key="step.id">
          <GameDaySection
            :class="`game-day-stack__section--${group.id}`"
            :no="step.no"
            :title="step.title"
            :summary="step.summary"
            :state="step.state"
            :collapsible="step.hasBody"
            :open="!!open[step.id]"
            :lazy="step.lazy"
            :test-id="`section-${step.slug}`"
            @update:open="emit('update:open', step.id, $event)"
          >
            <template v-if="step.link" #actions>
              <v-btn
                size="small"
                variant="outlined"
                class="game-day-stepper__secondary"
                :to="step.link.to"
                :data-testid="step.link.testId"
              >
                {{ step.link.label }}
              </v-btn>
            </template>
            <template v-if="step.hasBody" #default>
              <slot :name="`body-${step.id}`" />
            </template>
          </GameDaySection>
          <GameDaySection
            v-if="step.sub"
            :class="`game-day-stack__section--${group.id}`"
            no="–"
            :title="step.sub.title"
            state="info"
            lazy
            :open="!!open[step.sub.id]"
            :test-id="`section-${step.sub.slug}`"
            @update:open="emit('update:open', step.sub.id, $event)"
          >
            <slot :name="`body-${step.sub.id}`" />
          </GameDaySection>
        </template>
      </div>
    </div>
  </div>

  <!-- PC 幅: 上部のステッパー + タブ切り替え。順番は強制しない（どのステップにも直接行ける） -->
  <v-stepper
    v-else
    :model-value="active"
    :mobile="false"
    editable
    non-linear
    flat
    class="game-day-stepper mt-4"
    data-testid="game-day-stepper"
    @update:model-value="onSelect"
  >
    <v-stepper-header class="game-day-stepper__header">
      <template v-for="group in groups" :key="group.id">
        <div
          class="game-day-stepper__group"
          :class="`game-day-stepper__group--${group.id}`"
          role="group"
          :aria-label="t(`gameDay.phase.${group.id}`)"
          :data-testid="`step-group-${group.id}`"
        >
          <div class="game-day-stepper__items">
            <template v-for="step in group.steps" :key="step.id">
              <v-stepper-item
                :value="step.id"
                :title="step.title"
                :complete="step.state === 'done'"
                :error="step.state === 'warn'"
                :data-testid="`step-${step.slug}`"
                :data-state="step.state"
              >
                <template #icon>
                  <span class="gd-step-icon" :style="stateIconStyle(step.state)">
                    <v-icon size="small" aria-hidden="true">{{ step.icon }}</v-icon>
                    <span
                      v-if="hasStateBadge(step.state)"
                      class="gd-step-icon__badge"
                      data-testid="step-state-badge"
                      aria-hidden="true"
                    >
                      <v-icon size="x-small">{{ STAGE_STATE_APPEARANCE[step.state].icon }}</v-icon>
                    </span>
                  </span>
                </template>
                <template #subtitle>
                  <GameDayStateChip v-if="step.state !== 'info'" :state="step.state" />
                </template>
              </v-stepper-item>
            </template>
          </div>
        </div>
      </template>
    </v-stepper-header>

    <div class="game-day-stepper__panels">
      <template v-for="step in steps" :key="step.id">
        <section
          v-show="step.id === active"
          class="game-day-stepper__panel"
          role="region"
          :aria-label="step.title"
          :data-testid="`panel-${step.slug}`"
          :data-state="step.state"
        >
          <div class="d-flex flex-wrap align-center ga-2 mb-2">
            <h2 class="text-subtitle-1 font-weight-bold">{{ step.no }}. {{ step.title }}</h2>
            <span v-if="step.summary" class="text-body-2 text-medium-emphasis">{{
              step.summary
            }}</span>
            <v-spacer />
            <v-btn
              v-if="step.link"
              size="small"
              variant="outlined"
              class="game-day-stepper__secondary"
              :to="step.link.to"
              :data-testid="step.link.testId"
            >
              {{ step.link.label }}
            </v-btn>
          </div>
          <slot
            v-if="step.hasBody && (!step.lazy || visited.has(step.id))"
            :name="`body-${step.id}`"
          />
          <GameDaySection
            v-if="step.sub"
            class="mt-4"
            no="–"
            :title="step.sub.title"
            state="info"
            lazy
            :open="!!open[step.sub.id]"
            :test-id="`section-${step.sub.slug}`"
            @update:open="emit('update:open', step.sub.id, $event)"
          >
            <slot :name="`body-${step.sub.id}`" />
          </GameDaySection>
        </section>
      </template>
    </div>
  </v-stepper>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import type { RouteLocationRaw } from 'vue-router'
import GameDaySection from './GameDaySection.vue'
import GameDayStateChip from './GameDayStateChip.vue'
import { STAGE_STATE_APPEARANCE, type StageState } from './gameDayStatus'

export interface GameDayStepSub {
  id: string
  slug: string
  title: string
}

export interface GameDayStep {
  id: string
  slug: string
  group: 'registration' | 'game'
  no: number
  icon: string
  title: string
  summary?: string
  state: StageState
  // true: 本文（入力欄など）がある。false: 別画面への入口だけを置く段
  hasBody: boolean
  // true: 初めて開かれるまで中身を描画しない（重い部品を遅延させる）
  lazy?: boolean
  link?: { to: RouteLocationRaw; label: string; testId: string }
  // 親の段の中（スマホ幅では直後の段）に置く補助の段（投手状態）
  sub?: GameDayStepSub
}

const props = defineProps<{
  steps: GameDayStep[]
  mode: 'tabs' | 'stack'
  // 選択中のステップ（PC 幅）
  active: string
  // 開いている段（スマホ幅）。補助の段の id も含む
  open: Record<string, boolean>
}>()

const emit = defineEmits<{
  'update:active': [id: string]
  'update:open': [id: string, value: boolean]
}>()

const { t } = useI18n()
const groupIcon = (id: 'registration' | 'game') =>
  id === 'registration' ? 'mdi-account-switch' : 'mdi-baseball-diamond'
const hasStateBadge = (state: StageState) =>
  state === 'done' || state === 'todo' || state === 'warn'
const stateIconStyle = (state: StageState) => {
  const color = STAGE_STATE_APPEARANCE[state].color
  return {
    '--gd-step-bg': `rgb(var(--v-theme-${color}))`,
    '--gd-step-ink': `rgb(var(--v-theme-on-${color}))`,
  }
}

const groups = computed(() =>
  (['registration', 'game'] as const)
    .map((id) => ({
      id,
      steps: props.steps.filter((s) => s.group === id),
    }))
    .filter((group) => group.steps.length > 0),
)

// 遅延させる段は、一度選ばれたら描画したままにする（切り替えで入力中の値を失わない）
const visited = reactive(new Set<string>())
watch(
  () => props.active,
  (id) => visited.add(id),
  { immediate: true },
)

const onSelect = (id: unknown) => {
  if (typeof id === 'string') emit('update:active', id)
}
</script>

<style scoped>
.game-day-phase {
  font-weight: 700;
  letter-spacing: 0.08em;
  display: flex;
  align-items: center;
  gap: 5px;
}
.game-day-stack__group {
  border-top: 3px solid;
  padding-top: 2px;
}
.game-day-stack__group--registration {
  border-color: rgb(var(--v-theme-on-zone-roster));
}
.game-day-stack__group--game {
  border-color: rgb(var(--v-theme-on-zone-game));
}
.game-day-stack__group--registration .game-day-phase {
  color: rgb(var(--v-theme-on-zone-roster));
}
.game-day-stack__group--game .game-day-phase {
  color: rgb(var(--v-theme-on-zone-game));
}
.game-day-stack__section--registration {
  background: rgb(var(--v-theme-zone-roster));
  color: rgb(var(--v-theme-on-surface));
}
.game-day-stack__section--game {
  background: rgb(var(--v-theme-zone-game));
  color: rgb(var(--v-theme-on-surface));
}
.game-day-stack :deep(.game-day-section__summary) {
  color: rgba(var(--v-theme-on-surface), 0.85);
}
.game-day-stepper {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
}
.game-day-stepper__header {
  box-shadow: none;
  align-items: stretch;
  flex-direction: row;
  gap: 4px;
  padding: 4px 8px;
  border-bottom: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
}
.game-day-stepper__group {
  display: flex;
  flex-direction: row;
  flex: 3 1 0;
  min-width: 0;
  border-radius: 6px;
  border-top: 3px solid;
}
.game-day-stepper__group--registration {
  background: rgb(var(--v-theme-zone-roster));
  border-color: rgb(var(--v-theme-on-zone-roster));
}
.game-day-stepper__group--game {
  flex-grow: 4;
  background: rgb(var(--v-theme-zone-game));
  border-color: rgb(var(--v-theme-on-zone-game));
}
.game-day-stepper__items {
  display: flex;
  flex: 1 1 auto;
  min-width: 0;
  align-items: stretch;
  gap: 2px;
}
.game-day-stepper :deep(.v-stepper-item) {
  flex: 1 1 0;
  min-width: 0;
  padding: 8px 8px;
  border-radius: 6px;
  min-height: 56px;
  opacity: 1;
  color: rgb(var(--v-theme-on-surface));
}
.game-day-stepper :deep(.v-stepper-item__avatar.v-avatar) {
  margin-inline-end: 6px;
  background: rgb(var(--v-theme-surface));
  overflow: visible;
}
.game-day-stepper :deep(.v-stepper-item--selected) {
  box-shadow:
    inset 0 -3px 0 rgb(var(--v-theme-link)),
    inset 0 0 0 1px rgb(var(--v-theme-link));
  background: rgb(var(--v-theme-surface));
}
.gd-step-icon {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  background: var(--gd-step-bg);
  color: var(--gd-step-ink);
}
.gd-step-icon__badge {
  position: absolute;
  right: -8px;
  bottom: -7px;
  display: grid;
  place-items: center;
  width: 18px;
  height: 18px;
  border: 2px solid rgb(var(--v-theme-surface));
  border-radius: 50%;
  background: var(--gd-step-bg);
  color: var(--gd-step-ink);
}
.game-day-stepper :deep(.v-stepper-item__title) {
  line-height: 1.3;
  font-weight: 700;
  font-size: 0.875rem;
}
.game-day-stepper :deep(.v-stepper-item__subtitle) {
  margin-top: 4px;
  line-height: 1.2;
  opacity: 1;
}
.game-day-stepper__panels {
  padding: 16px;
}
.game-day-stepper__secondary {
  border-color: rgb(var(--v-theme-border-strong));
  color: rgb(var(--v-theme-on-surface));
}
</style>
