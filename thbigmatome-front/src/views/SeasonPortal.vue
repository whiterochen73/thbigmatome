<template>
  <PageLayout width="wide">
    <!-- 「いま」の帯。現在日は日程の結果から自動で決まる（最後に結果が入った日の翌日〜次の試合日の、最後の試合日）。動かす操作は無い -->
    <template v-if="!loading && season" #lead>
      <v-card class="now-strip" data-testid="now-strip">
        <v-icon class="on-surface-variant" size="26" aria-hidden="true">mdi-calendar-today</v-icon>
        <div class="now-strip__date" data-testid="current-date">
          <span class="now-strip__label">{{ t('seasonPortal.currentDate') }}</span>
          <span class="now-strip__value">{{ currentDateStr }}</span>
        </div>
        <span
          v-if="currentDaySchedule"
          class="type-badge"
          :class="`badge-${getTypeCategory(currentDaySchedule.date_type)}`"
          data-testid="now-type"
        >
          <v-icon size="x-small" class="mr-1">{{
            dateTypeIcon(currentDaySchedule.date_type)
          }}</v-icon>
          {{ t(`settings.schedule.dateTypes.${currentDaySchedule.date_type}`) }}
        </span>
        <span
          v-if="dayMark(currentDaySchedule)"
          class="day-mark"
          :class="`day-mark--${dayMark(currentDaySchedule)}`"
          :title="dayMarkTitle(currentDaySchedule)"
          data-testid="now-mark"
          >{{ t(`seasonPortal.calendarMark.${dayMark(currentDaySchedule)}`) }}</span
        >
        <v-spacer />
        <v-btn
          :color="isCalendarTab ? 'action' : undefined"
          :variant="isCalendarTab ? 'flat' : 'outlined'"
          :style="isCalendarTab ? undefined : { borderColor: 'rgb(var(--v-theme-border-strong))' }"
          append-icon="mdi-arrow-right"
          :to="gameResultRoute"
          :disabled="!isGameDayToday"
          data-testid="go-to-game"
        >
          {{ t('seasonPortal.goToGameResult') }}
        </v-btn>
      </v-card>
    </template>

    <template v-if="!loading && season" #tabs>
      <v-tabs v-model="activeTab" color="link">
        <v-tab value="calendar">
          <v-icon start>mdi-calendar</v-icon>
          {{ t('seasonPortal.tabs.calendar') }}
        </v-tab>
        <v-tab value="members">
          <v-icon start>mdi-account-cog</v-icon>
          {{ t('seasonPortal.tabs.members') }}
        </v-tab>
        <v-tab value="roster">
          <v-icon start>mdi-account-group</v-icon>
          {{ t('seasonPortal.tabs.roster') }}
        </v-tab>
        <v-tab value="promotion_history">
          <v-icon start>mdi-swap-vertical</v-icon>
          {{ t('seasonPortal.tabs.promotionHistory') }}
        </v-tab>
        <v-tab value="absences">
          <v-icon start>mdi-account-off</v-icon>
          {{ t('seasonPortal.tabs.absences') }}
        </v-tab>
        <!-- リリース非表示: オーダータブ
        <v-tab value="lineup">
          <v-icon start>mdi-format-list-numbered</v-icon>
          {{ t('seasonPortal.tabs.lineup') }}
        </v-tab>
        -->
        <!-- リリース非表示: 成績タブ
        <v-tab value="stats">
          <v-icon start>mdi-chart-bar</v-icon>
          {{ t('seasonPortal.tabs.stats') }}
        </v-tab>
        -->
      </v-tabs>
    </template>

    <!-- ローディング中 -->
    <v-skeleton-loader v-if="loading" type="card" />

    <!-- シーズン未作成: インライン初期化フォーム -->
    <v-card v-if="!loading && !season" variant="outlined" class="mx-auto" max-width="480">
      <v-card-title class="text-h6 pa-4">
        <v-icon start>mdi-calendar-plus</v-icon>
        {{ t('seasonPortal.initForm.title') }}
      </v-card-title>
      <v-card-text>
        <template v-if="schedules.length === 0">
          <v-alert type="info" variant="tonal">
            {{ t('seasonPortal.initForm.noSchedules') }}
          </v-alert>
        </template>
        <template v-else>
          <v-select
            v-model="selectedScheduleId"
            :items="schedules"
            item-title="name"
            item-value="id"
            :label="t('seasonPortal.initForm.selectScheduleLabel')"
            class="mb-2"
          />
        </template>
      </v-card-text>
      <v-card-actions v-if="schedules.length > 0">
        <v-spacer />
        <v-btn
          color="action"
          variant="flat"
          :disabled="!selectedScheduleId || creating"
          :loading="creating"
          @click="createSeason"
        >
          {{ t('seasonPortal.initForm.startButton') }}
        </v-btn>
      </v-card-actions>
    </v-card>

    <v-tabs-window v-if="!loading && season" v-model="activeTab">
      <!-- タブ1: カレンダー -->
      <v-tabs-window-item value="calendar">
        <!-- 特例選手選択カード -->
        <v-card variant="outlined" class="pa-3">
          <div class="d-flex align-center flex-wrap" style="gap: 12px">
            <span class="text-body-2 font-weight-bold">{{
              t('seasonPortal.keyPlayer.label')
            }}</span>
            <template v-if="isCommissioner">
              <v-select
                v-model="selectedKeyPlayerId"
                :items="keyPlayerOptions"
                item-title="name"
                item-value="id"
                :placeholder="t('seasonPortal.keyPlayer.placeholder')"
                density="compact"
                hide-details
                clearable
                style="max-width: 280px"
              />
              <!-- 「今日の試合へ」が画面唯一の塗りの緑。保存は副操作（枠） -->
              <v-btn
                color="link"
                variant="outlined"
                size="small"
                :style="{ borderColor: 'rgb(var(--v-theme-border-strong))' }"
                :loading="keyPlayerSaving"
                :disabled="keyPlayerSaving"
                @click="saveKeyPlayer"
              >
                {{ t('seasonPortal.keyPlayer.save') }}
              </v-btn>
            </template>
            <template v-else>
              <span class="text-body-2">{{
                season.key_player_name ?? t('seasonPortal.keyPlayer.notSet')
              }}</span>
            </template>
          </div>
        </v-card>
        <v-card variant="outlined" class="pa-4 mt-4">
          <!-- ツールバー: 月ナビ + ビュー切替 -->
          <div class="cal-toolbar mb-4">
            <div class="month-nav">
              <v-btn icon variant="outlined" size="small" @click="prevMonth">
                <v-icon>mdi-chevron-left</v-icon>
              </v-btn>
              <h2 class="month-label">{{ monthStr }}</h2>
              <v-btn icon variant="outlined" size="small" @click="nextMonth">
                <v-icon>mdi-chevron-right</v-icon>
              </v-btn>
            </div>
            <v-btn-toggle
              v-model="viewMode"
              mandatory
              density="compact"
              variant="outlined"
              selected-class="bg-primary"
              :style="{ borderColor: 'rgb(var(--v-theme-border-strong))' }"
            >
              <v-btn value="calendar" title="カレンダー表示">
                <v-icon>mdi-calendar-month</v-icon>
              </v-btn>
              <v-btn value="table" title="リスト表示">
                <v-icon>mdi-format-list-bulleted</v-icon>
              </v-btn>
            </v-btn-toggle>
          </div>

          <!-- カレンダーグリッドビュー -->
          <template v-if="viewMode === 'calendar'">
            <div class="cal-wrapper">
              <div class="calendar-grid">
                <!-- 曜日ヘッダー -->
                <div
                  v-for="day in weekdays"
                  :key="day"
                  class="weekday-header text-center font-weight-bold"
                >
                  {{ day }}
                </div>
                <!-- 日付セル -->
                <div
                  v-for="day in calendarDays"
                  :key="day.date.toISOString()"
                  :class="[
                    'day-cell',
                    {
                      'is-current-day': day.isCurrentDay,
                      'not-current-month': !day.isCurrentMonth,
                      weekend: day.isWeekend && day.isCurrentMonth,
                    },
                  ]"
                  @click="openDayDetail(day)"
                >
                  <div class="day-num-wrapper">
                    <span class="day-number" :class="{ 'today-circle': day.isCurrentDay }">
                      {{ day.date.getDate() }}
                    </span>
                  </div>

                  <div v-if="day.isCurrentMonth && day.schedule" class="cell-content">
                    <!-- 日程種別チップ (未来日はv-menuで編集可) -->
                    <v-menu v-if="!isDateBeforeCurrent(day.date)">
                      <template #activator="{ props }">
                        <span
                          v-bind="props"
                          class="type-chip"
                          :class="`chip-${getTypeCategory(day.schedule.date_type)}`"
                          :title="t(`settings.schedule.dateTypes.${day.schedule.date_type}`)"
                          @click.stop
                        >
                          <v-icon size="x-small" class="mr-1">{{
                            dateTypeIcon(day.schedule.date_type)
                          }}</v-icon>
                          <span class="type-chip__text">{{
                            t(`settings.schedule.dateTypes.${day.schedule.date_type}`)
                          }}</span>
                        </span>
                      </template>
                      <v-list>
                        <v-list-item
                          v-for="dateType in dateTypes"
                          :key="dateType"
                          @click="updateSchedule(day.schedule, dateType)"
                        >
                          <v-list-item-title>{{
                            t(`settings.schedule.dateTypes.${dateType}`)
                          }}</v-list-item-title>
                        </v-list-item>
                      </v-list>
                    </v-menu>
                    <span
                      v-else
                      class="type-chip"
                      :class="`chip-${getTypeCategory(day.schedule.date_type)}`"
                      :title="t(`settings.schedule.dateTypes.${day.schedule.date_type}`)"
                    >
                      <v-icon size="x-small" class="mr-1">{{
                        dateTypeIcon(day.schedule.date_type)
                      }}</v-icon>
                      <span class="type-chip__text">{{
                        t(`settings.schedule.dateTypes.${day.schedule.date_type}`)
                      }}</span>
                    </span>

                    <!-- 試合情報 -->
                    <template v-if="isGameType(day.schedule.date_type)">
                      <div
                        v-if="day.schedule.game_result && !isCancelledType(day.schedule.date_type)"
                        class="game-info"
                      >
                        <span class="opponent-text"
                          >vs {{ day.schedule.game_result.opponent_short_name }}</span
                        >
                        <span
                          :class="`result-mark result-${day.schedule.game_result.result}`"
                          data-testid="calendar-result-mark"
                          >{{ resultMark(day.schedule.game_result.result) }}</span
                        >
                        <!-- ノーゲームは得点を出さない（勝敗・成績に入れない。台帳 D-11） -->
                        <span
                          v-if="day.schedule.game_result.score"
                          class="score-text"
                          data-testid="calendar-score"
                          >{{ day.schedule.game_result.score }}</span
                        >
                      </div>
                      <div v-else class="game-info">
                        <span v-if="day.schedule.announced_starter" class="starter-text">
                          {{ t('seasonPortal.announcedStarterPrefix') }}:
                          {{ day.schedule.announced_starter.name }}
                        </span>
                      </div>
                      <span
                        v-if="dayMark(day.schedule)"
                        class="day-mark"
                        :class="`day-mark--${dayMark(day.schedule)}`"
                        :title="dayMarkTitle(day.schedule)"
                        data-testid="calendar-day-mark"
                        >{{ t(`seasonPortal.calendarMark.${dayMark(day.schedule)}`) }}</span
                      >
                    </template>
                  </div>
                </div>
              </div>
            </div>

            <!-- 凡例 -->
            <div class="calendar-legend mt-3">
              <div class="legend-inner">
                <span v-for="item in legendItems" :key="item.type" class="legend-item">
                  <span class="legend-dot" :class="`chip-${getTypeCategory(item.type)}`"></span>
                  {{ t(`settings.schedule.dateTypes.${item.type}`) }}
                </span>
                <span class="legend-results ml-auto">
                  <span class="result-mark result-win">W</span
                  >{{ t('seasonPortal.legendWin') }}&nbsp;
                  <span class="result-mark result-lose">L</span
                  >{{ t('seasonPortal.legendLose') }}&nbsp;
                  <span class="result-mark result-draw">D</span
                  >{{ t('seasonPortal.legendDraw') }}&nbsp;
                  <span data-testid="legend-no-game">
                    <span class="result-mark result-no_game">NG</span
                    >{{ t('seasonPortal.legendNoGame') }}
                  </span>
                </span>
              </div>
            </div>
          </template>

          <!-- 表形式ビュー -->
          <template v-else>
            <div class="d-flex align-center mb-3 flex-wrap" style="gap: 8px">
              <span class="text-caption text-medium-emphasis"
                >{{ t('seasonPortal.viewLabel') }}：</span
              >
              <v-btn-toggle
                v-model="tableFilter"
                mandatory
                density="compact"
                variant="outlined"
                selected-class="bg-primary"
                size="small"
                :style="{ borderColor: 'rgb(var(--v-theme-border-strong))' }"
              >
                <v-btn value="all">{{ t('seasonPortal.viewAll') }}</v-btn>
                <v-btn value="game">{{ t('seasonPortal.viewGameOnly') }}</v-btn>
              </v-btn-toggle>
            </div>
            <div class="table-wrapper">
              <table class="schedule-table">
                <thead>
                  <tr>
                    <th>{{ t('seasonPortal.tableHeaders.date') }}</th>
                    <th>{{ t('seasonPortal.tableHeaders.dow') }}</th>
                    <th>{{ t('seasonPortal.tableHeaders.type') }}</th>
                    <th>{{ t('seasonPortal.tableHeaders.opponent') }}</th>
                    <th>{{ t('seasonPortal.tableHeaders.starter') }}</th>
                    <th>{{ t('seasonPortal.tableHeaders.score') }}</th>
                    <th>{{ t('seasonPortal.tableHeaders.result') }}</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="row in filteredTableRows"
                    :key="row.date.toISOString()"
                    :class="{ 'today-row': row.isCurrentDay }"
                  >
                    <td :data-label="t('seasonPortal.tableHeaders.date')" class="date-cell">
                      {{ formatTableDate(row.date) }}
                    </td>
                    <td :data-label="t('seasonPortal.tableHeaders.dow')" class="dow-cell">
                      {{ getDowLabel(row.dayOfWeek) }}
                    </td>
                    <td :data-label="t('seasonPortal.tableHeaders.type')">
                      <span
                        v-if="row.schedule"
                        class="type-badge"
                        :class="`badge-${getTypeCategory(row.schedule.date_type)}`"
                      >
                        <v-icon size="x-small" class="mr-1">{{
                          dateTypeIcon(row.schedule.date_type)
                        }}</v-icon>
                        {{ t(`settings.schedule.dateTypes.${row.schedule.date_type}`) }}
                      </span>
                      <span v-else class="text-disabled">—</span>
                    </td>
                    <td :data-label="t('seasonPortal.tableHeaders.opponent')">
                      <template
                        v-if="row.schedule?.game_result && !isCancelledType(row.schedule.date_type)"
                      >
                        {{ row.schedule.game_result.opponent_short_name }}
                      </template>
                      <span v-else class="text-disabled">—</span>
                    </td>
                    <td :data-label="t('seasonPortal.tableHeaders.starter')">
                      <template
                        v-if="
                          row.schedule &&
                          !row.schedule.game_result &&
                          row.schedule.announced_starter
                        "
                      >
                        {{ row.schedule.announced_starter.name }}
                      </template>
                      <span v-else class="text-disabled">—</span>
                    </td>
                    <td
                      :data-label="t('seasonPortal.tableHeaders.score')"
                      data-testid="table-score"
                    >
                      {{
                        !isCancelledType(row.schedule?.date_type) &&
                        row.schedule?.game_result?.score
                          ? row.schedule.game_result.score
                          : '—'
                      }}
                    </td>
                    <td :data-label="t('seasonPortal.tableHeaders.result')">
                      <span
                        v-if="row.schedule?.game_result && !isCancelledType(row.schedule.date_type)"
                        class="result-badge"
                        :class="`result-${row.schedule.game_result.result}`"
                        data-testid="table-result-badge"
                      >
                        {{ resultMark(row.schedule.game_result.result) }}
                      </span>
                      <span v-else class="text-disabled">—</span>
                    </td>
                    <td>
                      <span
                        v-if="row.schedule && dayMark(row.schedule)"
                        class="day-mark mr-1"
                        :class="`day-mark--${dayMark(row.schedule)}`"
                        :title="dayMarkTitle(row.schedule)"
                        data-testid="table-day-mark"
                        >{{ t(`seasonPortal.calendarMark.${dayMark(row.schedule)}`) }}</span
                      >
                      <v-btn
                        v-if="row.schedule"
                        size="x-small"
                        color="link"
                        variant="text"
                        :to="{
                          name: 'GameResult',
                          params: { teamId, scheduleId: row.schedule.id },
                        }"
                      >
                        {{
                          isGameType(row.schedule.date_type)
                            ? t('seasonPortal.gameResultInput')
                            : t('seasonPortal.openSchedule')
                        }}
                      </v-btn>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </template>
        </v-card>
      </v-tabs-window-item>

      <!-- タブ2: チーム編成 -->
      <v-tabs-window-item value="members">
        <div>
          <AsOfDateBar
            v-if="asOfDate"
            v-model:date="asOfDate"
            v-model:phase="asOfPhase"
            show-phase
            :min="dateOnly(season.start_date)"
            :max="dateOnly(season.end_date)"
            :current-date="currentDateKey"
          />
          <TeamMembers
            v-if="asOfDate"
            :team-id="teamId"
            :as-of-date="asOfDate"
            :phase="asOfPhase"
          />
        </div>
      </v-tabs-window-item>

      <!-- タブ3: ロスター -->
      <v-tabs-window-item value="roster">
        <div>
          <AsOfDateBar
            v-if="asOfDate"
            v-model:date="asOfDate"
            v-model:phase="asOfPhase"
            show-phase
            :min="dateOnly(season.start_date)"
            :max="dateOnly(season.end_date)"
            :current-date="currentDateKey"
          />
          <SeasonRosterTab
            v-if="asOfDate"
            :team-id="teamId"
            :as-of-date="asOfDate"
            :phase="asOfPhase"
          />
        </div>
      </v-tabs-window-item>

      <!-- タブ4: 昇降格履歴 -->
      <v-tabs-window-item value="promotion_history">
        <div>
          <PromotionHistoryTab :team-id="teamId" :season-id="season?.id ?? null" />
        </div>
      </v-tabs-window-item>

      <!-- タブ5: 離脱者 -->
      <v-tabs-window-item value="absences">
        <div>
          <AsOfDateBar
            v-if="asOfDate"
            v-model:date="asOfDate"
            :min="dateOnly(season.start_date)"
            :max="dateOnly(season.end_date)"
            :current-date="currentDateKey"
          />
          <SeasonAbsenceTab v-if="asOfDate" :team-id="teamId" :as-of-date="asOfDate" />
        </div>
      </v-tabs-window-item>

      <!-- リリース非表示: オーダータブ（タブ6）
      <v-tabs-window-item value="lineup">
        <div>
          <v-tabs v-model="lineupSubTab" color="link" density="compact" class="mb-2">
            <v-tab value="template">
              <v-icon start size="small">mdi-pencil</v-icon>
              テンプレート編集
            </v-tab>
            <v-tab value="generate">
              <v-icon start size="small">mdi-text-box-edit</v-icon>
              テキスト生成
            </v-tab>
          </v-tabs>
          <v-tabs-window v-model="lineupSubTab">
            <v-tabs-window-item value="template">
              <LineupTemplateEditor :team-id="teamId" />
            </v-tabs-window-item>
            <v-tabs-window-item value="generate">
              <SquadTextGenerator :team-id="teamId" />
            </v-tabs-window-item>
          </v-tabs-window>
        </div>
      </v-tabs-window-item>
      -->
    </v-tabs-window>
  </PageLayout>

  <!-- 日程詳細ダイアログ (モバイル用タップ詳細) -->
  <v-dialog v-model="isDayDetailOpen" max-width="400px">
    <v-card v-if="selectedDay">
      <v-card-title class="d-flex align-center pt-3 pb-1">
        <span>{{ formatDetailDate(selectedDay.date) }}</span>
        <v-spacer />
        <v-btn icon size="small" variant="text" @click="isDayDetailOpen = false">
          <v-icon>mdi-close</v-icon>
        </v-btn>
      </v-card-title>
      <v-card-text class="pt-2">
        <div v-if="selectedDay.schedule">
          <div class="mb-3">
            <span class="text-caption text-medium-emphasis"
              >{{ t('seasonPortal.detailDialog.type') }}&ensp;</span
            >
            <span
              class="type-badge"
              :class="`badge-${getTypeCategory(selectedDay.schedule.date_type)}`"
            >
              <v-icon size="x-small" class="mr-1">{{
                dateTypeIcon(selectedDay.schedule.date_type)
              }}</v-icon>
              {{ t(`settings.schedule.dateTypes.${selectedDay.schedule.date_type}`) }}
            </span>
          </div>
          <template v-if="isGameType(selectedDay.schedule.date_type)">
            <template
              v-if="
                selectedDay.schedule.game_result && !isCancelledType(selectedDay.schedule.date_type)
              "
            >
              <div class="mb-1">
                <span class="text-caption text-medium-emphasis"
                  >{{ t('seasonPortal.detailDialog.opponent') }}&ensp;</span
                >
                vs {{ selectedDay.schedule.game_result.opponent_short_name }}
              </div>
              <div
                v-if="selectedDay.schedule.game_result.score"
                class="mb-1"
                data-testid="detail-score"
              >
                <span class="text-caption text-medium-emphasis"
                  >{{ t('seasonPortal.detailDialog.score') }}&ensp;</span
                >
                {{ selectedDay.schedule.game_result.score }}
              </div>
              <div class="mb-2" data-testid="detail-result">
                <span class="text-caption text-medium-emphasis"
                  >{{ t('seasonPortal.detailDialog.result') }}&ensp;</span
                >
                <span
                  :class="`result-mark result-${selectedDay.schedule.game_result.result}`"
                  style="font-size: 1.1rem"
                  >{{ resultMark(selectedDay.schedule.game_result.result) }}</span
                >
                {{
                  selectedDay.schedule.game_result.result === 'win'
                    ? t('seasonPortal.detailDialog.win')
                    : selectedDay.schedule.game_result.result === 'lose'
                      ? t('seasonPortal.detailDialog.lose')
                      : selectedDay.schedule.game_result.result === 'no_game'
                        ? t('seasonPortal.detailDialog.noGame')
                        : t('seasonPortal.detailDialog.draw')
                }}
              </div>
            </template>
            <template v-else>
              <div v-if="selectedDay.schedule.announced_starter" class="mb-2">
                <span class="text-caption text-medium-emphasis"
                  >{{ t('seasonPortal.detailDialog.starter') }}&ensp;</span
                >
                {{ selectedDay.schedule.announced_starter.name }}
              </div>
            </template>
            <div
              v-if="dayMark(selectedDay.schedule)"
              class="day-mark-note mb-2"
              :class="`day-mark-note--${dayMark(selectedDay.schedule)}`"
              data-testid="detail-day-mark"
            >
              <span class="day-mark" :class="`day-mark--${dayMark(selectedDay.schedule)}`">{{
                t(`seasonPortal.calendarMark.${dayMark(selectedDay.schedule)}`)
              }}</span>
              {{ dayMarkTitle(selectedDay.schedule) }}
            </div>
          </template>
          <v-btn
            color="action"
            variant="flat"
            block
            class="mt-2"
            data-testid="detail-open-schedule"
            :to="{
              name: 'GameResult',
              params: { teamId, scheduleId: selectedDay.schedule.id },
            }"
            @click="isDayDetailOpen = false"
          >
            {{
              isGameType(selectedDay.schedule.date_type)
                ? t('seasonPortal.gameResultInput')
                : t('seasonPortal.openSchedule')
            }}
          </v-btn>
        </div>
        <div v-else class="text-center text-caption text-medium-emphasis py-4">
          {{ t('seasonPortal.noSchedule') }}
        </div>
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { dateTypeAppearance } from '@/components/gameDay/dateTypeAppearance'
import { ref, onMounted, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import type { SeasonDetail } from '@/types/seasonDetail'
import type { SeasonSchedule } from '@/types/seasonSchedule'
import type { ScheduleList } from '@/types/scheduleList'
import type { Team } from '@/types/team'
import SeasonRosterTab from '@/components/season/SeasonRosterTab.vue'
import SeasonAbsenceTab from '@/components/season/SeasonAbsenceTab.vue'
import AsOfDateBar from '@/components/season/AsOfDateBar.vue'
import PromotionHistoryTab from '@/components/season/PromotionHistoryTab.vue'
import TeamMembers from '@/views/TeamMembers.vue'
// リリース非表示: オーダータブ用コンポーネント（ポストリリースで復活予定）
// import LineupTemplateEditor from '@/components/squad/LineupTemplateEditor.vue'
// import SquadTextGenerator from '@/components/squad/SquadTextGenerator.vue'
import { useTeamSelectionStore } from '@/stores/teamSelection'
import { useAuth } from '@/composables/useAuth'
import { useAppBarTitle } from '@/composables/useAppBarTitle'
import PageLayout from '@/components/shared/PageLayout.vue'
import {
  calendarDayMark,
  hasGameDayArrived,
  isGameType,
  SCHEDULE_DATE_TYPES,
} from '@/components/gameDay/gameDayStatus'

const props = defineProps<{ teamId?: number }>()

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const teamSelectionStore = useTeamSelectionStore()
const { isCommissioner } = useAuth()
const loading = ref(true)
const season = ref<SeasonDetail | null>(null)
// 現在日 = 今の範囲の最後の試合日（サーバが日程の結果から導く。season.current_date）。カレンダーの表示月とは別に持つ
const currentDate = computed(() =>
  season.value?.current_date ? new Date(season.value.current_date) : new Date(),
)
// カレンダーに出す月（月送りで動く）。現在日の月で始まる
const calendarCursor = ref(new Date())

// 過去分の修正（チーム編成・ロスター・離脱者の各タブ）で読む日付と区分。GET と保存の POST に同じ値を渡す
const asOfDate = ref('')
const asOfPhase = ref('pre_game')
const dateOnly = (value: string | null | undefined): string => (value ? value.slice(0, 10) : '')
const currentDateKey = computed(() => dateOnly(season.value?.current_date))

// 画面のタイトル。シーズンには題を付けないので、チーム名をバーのタイトルに、「シーズン」をサブタイトルにする
// （チーム名が届くまでは「シーズン」だけを出す）
const teamName = ref('')
useAppBarTitle(() =>
  teamName.value
    ? { title: teamName.value, subtitle: t('seasonPortal.shortTitle') }
    : { title: t('seasonPortal.shortTitle') },
)

// シーズン初期化フォーム
const schedules = ref<ScheduleList[]>([])
const selectedScheduleId = ref<number | null>(null)
const creating = ref(false)

// 特例選手
type KeyPlayerOption = { id: number; name: string }
const keyPlayerOptions = ref<KeyPlayerOption[]>([])
const selectedKeyPlayerId = ref<number | null>(null)
const keyPlayerSaving = ref(false)

const teamId = props.teamId ?? parseInt(<string>route.params.teamId, 10)

// タブ状態をURLクエリパラメータで管理
const activeTab = ref((route.query.tab as string) || 'calendar')
// 画面の塗りの緑は 1 つまで。「今日の試合へ」が緑になるのはカレンダーの時だけ（チーム編成タブでは「保存」が主操作）
const isCalendarTab = computed(() => activeTab.value === 'calendar')

// オーダータブのサブタブ（リリース非表示中）
// const lineupSubTab = ref('template')

watch(activeTab, (newTab) => {
  if (newTab === 'stats') {
    router.push({ name: '成績集計' })
    return
  }
  router.replace({ query: { ...route.query, tab: newTab } })
})

watch(
  () => route.query.tab,
  (newTab) => {
    if (newTab && newTab !== activeTab.value) {
      activeTab.value = newTab as string
    }
  },
)

// ビュー切替 (localStorageで記憶)
const viewMode = ref<'calendar' | 'table'>(
  (localStorage.getItem('sp_view') as 'calendar' | 'table') || 'calendar',
)
watch(viewMode, (v) => localStorage.setItem('sp_view', v))

// 表ビューフィルタ
const tableFilter = ref<'all' | 'game'>('all')

// 日程詳細ダイアログ
type CalendarDay = {
  date: Date
  isCurrentMonth: boolean
  isCurrentDay: boolean
  isWeekend: boolean
  dayOfWeek: number
  schedule: SeasonSchedule | null | undefined
}
const isDayDetailOpen = ref(false)
const selectedDay = ref<CalendarDay | null>(null)

const openDayDetail = (day: CalendarDay) => {
  if (!day.isCurrentMonth) return
  selectedDay.value = day
  isDayDetailOpen.value = true
}

const fetchSeason = async () => {
  loading.value = true
  try {
    const response = await axios.get(`/teams/${teamId}/season`)
    season.value = response.data
    if (season.value) {
      calendarCursor.value = new Date(season.value.current_date)
      // 過去分の修正の既定の日付は現在日。試合日ページの「シーズン画面で修正する」リンクは ?date= で日付を渡す
      const requested = typeof route.query.date === 'string' ? route.query.date : ''
      asOfDate.value = /^\d{4}-\d{2}-\d{2}$/.test(requested)
        ? requested
        : dateOnly(season.value.current_date)
    }
  } catch (error) {
    console.error('Failed to fetch season data:', error)
  } finally {
    loading.value = false
  }
}

const fetchSchedules = async () => {
  try {
    const response = await axios.get<ScheduleList[]>('/schedules')
    schedules.value = response.data
  } catch (error) {
    console.error('Failed to fetch schedules:', error)
  }
}

const fetchKeyPlayerOptions = async () => {
  try {
    const response = await axios.get<KeyPlayerOption[]>(`/teams/${teamId}/team_memberships`)
    keyPlayerOptions.value = response.data
  } catch (error) {
    console.error('Failed to fetch team memberships:', error)
  }
}

const saveKeyPlayer = async () => {
  if (!season.value) return
  keyPlayerSaving.value = true
  try {
    await axios.patch(`/seasons/${season.value.id}`, {
      season: { key_player_id: selectedKeyPlayerId.value },
    })
    season.value.key_player_id = selectedKeyPlayerId.value
    const found = keyPlayerOptions.value.find((m) => m.id === selectedKeyPlayerId.value)
    season.value.key_player_name = found?.name ?? null
  } catch (error) {
    console.error('Failed to save key player:', error)
  } finally {
    keyPlayerSaving.value = false
  }
}

const fetchTeamName = async () => {
  try {
    const response = await axios.get<Team>(`/teams/${teamId}`)
    teamName.value = response.data.name
    teamSelectionStore.selectTeam(teamId, response.data.name)
  } catch {
    teamSelectionStore.selectTeam(teamId, '')
  }
}

const createSeason = async () => {
  if (!selectedScheduleId.value) return
  creating.value = true
  try {
    await axios.post('/seasons', {
      team_id: teamId,
      schedule_id: selectedScheduleId.value,
    })
    await fetchSeason()
  } catch (error) {
    console.error('Failed to create season:', error)
  } finally {
    creating.value = false
  }
}

const currentDateStr = computed(() => {
  return currentDate.value.toLocaleDateString('ja-JP', {
    month: 'long',
    day: 'numeric',
    weekday: 'short',
  })
})

const monthStr = computed(() => {
  return calendarCursor.value.toLocaleDateString('ja-JP', { year: 'numeric', month: 'long' })
})

const weekdays = computed(() => {
  const format = new Intl.DateTimeFormat('ja-JP', { weekday: 'short' })
  return [...Array(7).keys()].map((day) => {
    const date = new Date(Date.UTC(2021, 5, 7))
    date.setDate(date.getDate() + day)
    return format.format(date)
  })
})

const calendarDays = computed(() => {
  if (!season.value) return []

  const year = calendarCursor.value.getFullYear()
  const month = calendarCursor.value.getMonth()
  const startDate = new Date(year, month, 1)
  const endDate = new Date(year, month + 1, 0)

  const days: CalendarDay[] = []
  const startDayOfWeek = (startDate.getDay() + 6) % 7

  for (let i = startDayOfWeek; i > 0; i--) {
    const date = new Date(startDate)
    date.setDate(date.getDate() - i)
    days.push({
      date,
      isCurrentMonth: false,
      isCurrentDay: false,
      isWeekend: false,
      dayOfWeek: date.getDay(),
      schedule: null,
    })
  }

  for (let i = 1; i <= endDate.getDate(); i++) {
    const date = new Date(year, month, i)
    const isCurrentDay =
      date.getFullYear() === currentDate.value.getFullYear() &&
      date.getMonth() === currentDate.value.getMonth() &&
      date.getDate() === currentDate.value.getDate()
    const dayOfWeek = date.getDay()
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6

    const schedule = season.value?.season_schedules.find((s) => {
      const scheduleDate = new Date(s.date)
      return (
        scheduleDate.getFullYear() === date.getFullYear() &&
        scheduleDate.getMonth() === date.getMonth() &&
        scheduleDate.getDate() === date.getDate()
      )
    })
    days.push({ date, isCurrentMonth: true, isCurrentDay, isWeekend, dayOfWeek, schedule })
  }

  const endDayOfWeek = (endDate.getDay() + 6) % 7
  for (let i = 1; i < 7 - endDayOfWeek; i++) {
    const date = new Date(endDate)
    date.setDate(date.getDate() + i)
    days.push({
      date,
      isCurrentMonth: false,
      isCurrentDay: false,
      isWeekend: false,
      dayOfWeek: date.getDay(),
      schedule: null,
    })
  }

  return days
})

const prevMonth = () => {
  const cursor = calendarCursor.value
  calendarCursor.value = new Date(cursor.getFullYear(), cursor.getMonth() - 1, 1)
}

const nextMonth = () => {
  const cursor = calendarCursor.value
  calendarCursor.value = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1)
}

const dateTypes = SCHEDULE_DATE_TYPES

const legendItems = [
  { type: 'game_day' },
  { type: 'interleague_game_day' },
  { type: 'reserve_day' },
  { type: 'interleague_reserve_day' },
  { type: 'travel_day' },
  { type: 'no_game_day' },
  { type: 'no_game' },
]

const getTypeCategory = (dateType?: string) =>
  dateType ? dateTypeAppearance(dateType).category : 'empty'
const dateTypeIcon = (dateType?: string) => dateTypeAppearance(dateType).icon

// 雨天中止等のキャンセル系date_typeか判定
const isCancelledType = (dateType?: string) => dateTypeAppearance(dateType).cancelled

// 試合日のセルの印: 得点と登板記録の食い違い（要確認・赤）、試合日が来ているのに結果が未入力（黄）
const dayMark = (schedule?: SeasonSchedule | null): 'warn' | 'todo' | null => {
  if (!schedule || !isGameType(schedule.date_type) || isCancelledType(schedule.date_type)) {
    return null
  }
  return calendarDayMark({
    gameResult: schedule.game_result,
    appearanceCount: schedule.pitcher_appearance_count,
    arrived: hasGameDayArrived(schedule.date, season.value?.current_date),
  })
}

const dayMarkTitle = (schedule?: SeasonSchedule | null) => {
  const mark = dayMark(schedule)
  return mark ? t(`seasonPortal.calendarMark.${mark}Title`) : ''
}

// 勝敗マーク
const resultMark = (result: string) => {
  return ({ win: 'W', lose: 'L', draw: 'D', no_game: 'NG' } as Record<string, string>)[result] || ''
}

const isDateBeforeCurrent = (date: Date) => {
  if (!season.value || !season.value.current_date) return false
  const current = new Date(season.value.current_date)
  date.setHours(0, 0, 0, 0)
  current.setHours(0, 0, 0, 0)
  return date < current
}

const updateSchedule = async (schedule: SeasonSchedule, newDateType: string) => {
  try {
    await axios.patch(`/teams/${teamId}/season/season_schedules/${schedule.id}`, {
      season_schedule: { date_type: newDateType },
    })
    if (season.value) {
      const index = season.value.season_schedules.findIndex((s) => s.id === schedule.id)
      if (index !== -1) {
        season.value.season_schedules[index].date_type = newDateType
      }
    }
  } catch (error) {
    console.error('Failed to update schedule:', error)
  }
}

const currentDaySchedule = computed(() => {
  if (!season.value) return null
  const current = new Date(currentDate.value)
  current.setHours(0, 0, 0, 0)

  return season.value.season_schedules.find((s) => {
    const scheduleDate = new Date(s.date)
    scheduleDate.setHours(0, 0, 0, 0)
    return scheduleDate.getTime() === current.getTime()
  })
})

const isGameDayToday = computed(() => {
  if (!currentDaySchedule.value) return false
  return isGameType(currentDaySchedule.value.date_type)
})

const gameResultRoute = computed(() => {
  if (!isGameDayToday.value || !currentDaySchedule.value) return ''
  return {
    name: 'GameResult',
    params: {
      teamId: teamId,
      scheduleId: currentDaySchedule.value.id,
    },
  }
})

// 表ビュー: 当月の全日を行として生成
const tableRows = computed(() => calendarDays.value.filter((d) => d.isCurrentMonth))

const filteredTableRows = computed(() => {
  if (tableFilter.value === 'game') {
    return tableRows.value.filter((d) => isGameType(d.schedule?.date_type))
  }
  return tableRows.value
})

const DOW_LABELS = ['日', '月', '火', '水', '木', '金', '土']
const getDowLabel = (dow: number) => DOW_LABELS[dow]

const formatTableDate = (date: Date) => {
  return date.toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric' })
}

const formatDetailDate = (date: Date) => {
  const dow = DOW_LABELS[date.getDay()]
  return date.toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' }) + `（${dow}）`
}

onMounted(async () => {
  await Promise.all([fetchSeason(), fetchSchedules(), fetchTeamName()])
  if (season.value) {
    selectedKeyPlayerId.value = season.value.key_player_id
  }
  if (isCommissioner.value) {
    await fetchKeyPlayerOptions()
  }
})
</script>

<style scoped>
/* ===== 「いま」の帯 ===== */
.now-strip {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 14px;
  padding: 12px 16px;
}
.now-strip__date {
  display: flex;
  flex-direction: column;
}
.now-strip__label {
  font-size: 0.75rem;
  color: rgb(var(--v-theme-text-caption));
}
.now-strip__value {
  font-size: 1.25rem;
  font-weight: 700;
  line-height: 1.2;
}
@media (max-width: 599.98px) {
  .now-strip {
    padding: 10px 12px;
    gap: 10px;
  }
  .now-strip__value {
    font-size: 1.0625rem;
  }
  .now-strip > .v-btn {
    flex: 1 1 100%;
  }
}

/* ===== カレンダーツールバー ===== */
.cal-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 8px;
}
.month-nav {
  display: flex;
  align-items: center;
  gap: 8px;
}
.month-label {
  /* カード見出しはゴシック（global の h2 の明朝指定を使わない） */
  font-family: inherit;
  font-size: 1.2rem;
  font-weight: 700;
  min-width: 130px;
  text-align: center;
}

/* ===== カレンダーグリッド ===== */
.cal-wrapper {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  border-radius: 8px;
  overflow: hidden;
}

.calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 0;
}

.weekday-header {
  background-color: rgb(var(--v-theme-surface-variant));
  color: rgb(var(--v-theme-on-surface-variant));
  padding: 6px 2px;
  font-size: 0.85rem;
  font-weight: 700;
  border-bottom: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  text-align: center;
}

.day-cell {
  border: 1px solid rgba(var(--v-border-color), 0.12);
  padding: 5px;
  min-height: 95px;
  position: relative;
  cursor: pointer;
  transition: background 0.1s;
  vertical-align: top;
  overflow: hidden;
}
.day-cell:hover {
  background-color: rgba(var(--v-theme-primary), 0.04);
}

.day-num-wrapper {
  margin-bottom: 3px;
}
.day-number {
  font-size: 1rem;
  font-weight: 600;
  width: 26px;
  height: 26px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
}
.today-circle {
  background-color: rgb(var(--v-theme-primary));
  color: #fff;
}

.not-current-month {
  background-color: rgb(var(--v-theme-surface-variant));
  border-style: dashed;
  cursor: default;
}
.not-current-month .day-number {
  color: rgb(var(--v-theme-on-surface-variant));
}
.not-current-month:hover {
  background-color: rgb(var(--v-theme-surface-variant));
}
/* 土日は赤・青の文字や地にせず、地色（surface-variant）だけで区別する（赤は「負・要確認・削除」の意味に取っておく） */
.weekend {
  background-color: rgb(var(--v-theme-surface-variant));
}
.day-cell.weekend:hover {
  background-image: linear-gradient(
    rgba(var(--v-theme-primary), 0.06),
    rgba(var(--v-theme-primary), 0.06)
  );
}
.is-current-day {
  outline: 2px solid rgb(var(--v-theme-primary));
  outline-offset: -2px;
}

/* ===== セルコンテンツ ===== */
.cell-content {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.type-chip {
  display: block;
  font-size: 0.78rem;
  padding: 1px 5px;
  border-radius: 3px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  width: 100%;
  cursor: pointer;
  line-height: 1.5;
  font-weight: 500;
}

/* ===== 日程種別カラー (chip/badge共通) ===== */
/* 日付種類は寒色と無彩色で区別し、文字は対になる on-date-* を使う。 */

/* 試合日・プレーオフ日: 藍色 */
.chip-game,
.badge-game {
  background: rgb(var(--v-theme-date-game));
  color: rgb(var(--v-theme-on-date-game));
  font-weight: 700;
}

/* 交流戦試合日: 浅葱色 */
.chip-inter,
.badge-inter {
  background: rgb(var(--v-theme-date-interleague));
  color: rgb(var(--v-theme-on-date-interleague));
  font-weight: 700;
}

/* 予備日（通常ペナント）: 千草色 */
.chip-reserve,
.badge-reserve {
  background: rgb(var(--v-theme-date-reserve));
  color: rgb(var(--v-theme-on-date-reserve));
  font-weight: 500;
}

/* 交流戦予備日: 浅葱色 */
.chip-inter-reserve,
.badge-inter-reserve {
  background: rgb(var(--v-theme-date-interleague));
  color: rgb(var(--v-theme-on-date-interleague));
  font-weight: 400;
}

/* 移動日: 鼠色 */
.chip-travel,
.badge-travel {
  background: rgb(var(--v-theme-date-travel));
  color: rgb(var(--v-theme-on-date-travel));
  font-weight: 500;
}

/* 試合不可日（off系）: 無彩色 */
.chip-off,
.badge-off {
  background: rgb(var(--v-theme-state-neutral));
  color: rgb(var(--v-theme-on-state-neutral));
}

/* 雨天ノーゲーム・雨天中止: 取消線 + 薄い無彩色 */
.chip-no-game,
.badge-no-game {
  background: rgb(var(--v-theme-date-rain));
  color: rgb(var(--v-theme-on-date-rain));
  text-decoration: line-through;
}

.chip-empty,
.badge-empty {
  background: transparent;
  color: rgb(var(--v-theme-on-surface-variant));
}

/* ===== 試合情報 ===== */
.game-info {
  font-size: 0.85rem;
  line-height: 1.35;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 2px;
  color: rgb(var(--v-theme-on-surface));
}
.opponent-text {
  font-size: 0.85rem;
}
.starter-text {
  font-size: 0.8rem;
  color: rgb(var(--v-theme-on-surface-variant));
}
.score-text {
  font-size: 0.8rem;
  color: rgb(var(--v-theme-on-surface-variant));
}

.result-mark {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  min-height: 22px;
  padding: 0 4px;
  border-radius: 4px;
  font-weight: 700;
  font-size: 0.85rem;
}
.result-win {
  background: rgb(var(--v-theme-result-win));
  color: rgb(var(--v-theme-on-result-win));
}
.result-lose {
  background: rgb(var(--v-theme-result-loss));
  color: rgb(var(--v-theme-on-result-loss));
}
.result-draw {
  background: rgb(var(--v-theme-result-draw));
  color: rgb(var(--v-theme-on-result-draw));
}
/* ノーゲームは勝敗の色を付けない（勝敗・成績に入れない） */
.result-no_game {
  background: rgb(var(--v-theme-result-nogame));
  color: rgb(var(--v-theme-on-result-nogame));
  text-decoration: line-through;
}

/* 入力漏れの印。色だけで伝えないため文字を付ける（配色は試合日ページの状態チップと同じ） */
.day-mark {
  display: inline-block;
  border-radius: 10px;
  padding: 0 8px;
  font-size: 0.7rem;
  font-weight: 700;
  line-height: 18px;
  white-space: nowrap;
}
.day-mark--warn {
  background: #f7d9dc;
  color: #8a1420;
}
.day-mark--todo {
  background: #fbebc2;
  color: #7a5200;
}
.v-theme--dark .day-mark--warn {
  background: #5a1a22;
  color: #ffb3b8;
}
.v-theme--dark .day-mark--todo {
  background: #4d3a0c;
  color: #ffd777;
}
.day-mark-note {
  font-size: 0.85rem;
}

/* ===== 凡例 ===== */
.calendar-legend {
  padding: 6px 2px;
}
.legend-inner {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}
.legend-item {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 0.8rem;
  color: rgb(var(--v-theme-on-surface));
}
.legend-dot {
  width: 14px;
  height: 10px;
  border-radius: 3px;
  border: 1px solid rgb(var(--v-theme-border-strong));
  flex-shrink: 0;
  display: inline-block;
}
.legend-results {
  display: flex;
  align-items: center;
  gap: 3px;
  font-size: 0.85rem;
}

/* ===== 表形式ビュー ===== */
.table-wrapper {
  overflow-x: auto;
}
.schedule-table {
  width: 100%;
  border-collapse: collapse;
  background: rgb(var(--v-theme-surface));
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.07);
  font-size: 0.875rem;
}
.schedule-table th {
  background: rgb(var(--v-theme-primary));
  color: #fff;
  padding: 9px 12px;
  text-align: left;
  font-size: 0.8rem;
  font-weight: 600;
  white-space: nowrap;
}
.schedule-table td {
  padding: 7px 12px;
  font-size: 0.875rem;
  border-bottom: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  vertical-align: middle;
}
.schedule-table tr:last-child td {
  border-bottom: none;
}
.schedule-table tr:hover td {
  background: rgba(var(--v-theme-primary), 0.03);
}
.today-row > td {
  background-color: rgba(var(--v-theme-primary), 0.06) !important;
}

.type-badge {
  display: inline-block;
  padding: 2px 9px;
  border-radius: 12px;
  font-size: 0.78rem;
  font-weight: 600;
  white-space: nowrap;
}

.result-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  height: 22px;
  padding: 0 4px;
  border-radius: 4px;
  font-size: 0.85rem;
  font-weight: 700;
}

.result-badge.result-no_game {
  font-size: 0.7rem;
}

.date-cell {
  white-space: nowrap;
}
.dow-cell {
  white-space: nowrap;
}

/* ===== レスポンシブ ===== */
@media (max-width: 960px) {
  .day-cell {
    padding: 3px;
    min-height: 78px;
  }
  .day-number {
    font-size: 0.9rem;
    width: 22px;
    height: 22px;
  }
  .game-info {
    font-size: 0.8rem;
  }
}

@media (max-width: 600px) {
  .day-cell {
    padding: 2px;
    min-height: 62px;
  }
  .day-number {
    font-size: 0.85rem;
    width: 20px;
    height: 20px;
  }
  /* スマホ: 日程種別は文字を省きアイコンだけ（色と凡例で区別。詳細は日付をタップ） */
  .type-chip {
    padding: 1px 3px;
    text-align: center;
  }
  .type-chip__text {
    display: none;
  }
  .type-chip .v-icon {
    margin-inline-end: 0 !important;
  }
  /* モバイル: 試合情報はダイアログ表示のため非表示 */
  .game-info {
    display: none;
  }
  /* 曜日ヘッダーは非表示（日付一覧モード） */
  .weekday-header {
    display: none;
  }
  .month-label {
    font-size: 1rem;
    min-width: 100px;
  }
}

/* 表ビュー: モバイルはカード形式 */
@media (max-width: 768px) {
  .schedule-table thead {
    display: none;
  }
  .schedule-table,
  .schedule-table tbody,
  .schedule-table tr,
  .schedule-table td {
    display: block;
  }
  .schedule-table tr {
    background: rgb(var(--v-theme-surface));
    border-radius: 8px;
    margin-bottom: 8px;
    padding: 10px 14px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
    border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  }
  .schedule-table td {
    border-bottom: none !important;
    padding: 3px 0;
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 0.85rem;
  }
  .schedule-table td::before {
    content: attr(data-label);
    font-size: 0.78rem;
    color: rgb(var(--v-theme-on-surface-variant));
    min-width: 56px;
    flex-shrink: 0;
  }
  .today-row {
    border-color: rgb(var(--v-theme-primary)) !important;
    background: rgba(var(--v-theme-primary), 0.04) !important;
  }
}
</style>
