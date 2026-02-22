// src/router/index.ts
import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { authGuard } from './authGuard'
import LoginForm from '@/views/LoginForm.vue'
import DefaultLayout from '@/layouts/DefaultLayout.vue'
import TopMenu from '@/views/TopMenu.vue'
import ManagerList from '@/views/ManagerList.vue'
import Players from '@/views/Players.vue'
import CostAssignment from '@/views/CostAssignment.vue'

import Settings from '@/views/Settings.vue'

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'Login',
    component: LoginForm,
    meta: { requiresAuth: false },
  },
  {
    path: '/',
    component: DefaultLayout,
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        redirect: '/home',
      },
      {
        path: 'home',
        name: 'ホーム',
        component: () => import('@/views/HomeView.vue'),
        meta: { requiresAuth: true, title: 'ホーム' },
      },
      {
        path: 'menu',
        name: 'ダッシュボード',
        component: TopMenu,
        meta: { title: 'ダッシュボード' },
      },
      {
        path: 'managers',
        name: '監督一覧',
        component: ManagerList,
        meta: { title: '監督一覧' },
      },
      {
        path: '/teams',
        name: 'TeamList',
        component: () => import('@/views/TeamList.vue'),
        meta: { requiresAuth: true },
      },
      {
        path: '/teams/:teamId/members',
        name: 'TeamMembers',
        component: () => import('@/views/TeamMembers.vue'),
        meta: { requiresAuth: true, title: 'チームメンバー登録' },
      },
      {
        path: '/players',
        name: 'Players',
        component: Players,
        meta: { requiresAuth: true, title: '選手一覧' },
      },
      {
        path: '/cost_assignment',
        name: 'CostAssignment',
        component: CostAssignment,
        meta: { requiresAuth: true, title: 'コスト登録' },
      },
      {
        path: 'settings',
        name: '各種設定',
        component: Settings,
        meta: { title: '各種設定' },
      },
      {
        path: 'commissioner/leagues',
        name: 'Leagues',
        component: () => import('@/views/commissioner/LeaguesView.vue'),
        meta: { requiresAuth: true, requiresCommissioner: true, title: 'リーグ管理' },
      },
      {
        path: 'commissioner/stadiums',
        name: 'Stadiums',
        component: () => import('@/views/commissioner/StadiumsView.vue'),
        meta: { requiresAuth: true, requiresCommissioner: true, title: '球場管理' },
      },
      {
        path: 'commissioner/card_sets',
        name: 'CardSets',
        component: () => import('@/views/commissioner/CardSetsView.vue'),
        meta: { requiresAuth: true, requiresCommissioner: true, title: 'カードセット管理' },
      },
      {
        path: 'commissioner/competitions',
        name: 'Competitions',
        component: () => import('@/views/commissioner/CompetitionsView.vue'),
        meta: { requiresAuth: true, requiresCommissioner: true, title: '大会管理' },
      },
      {
        path: '/teams/:teamId/season',
        name: 'SeasonPortal',
        component: () => import('@/views/SeasonPortal.vue'),
        meta: { requiresAuth: true, title: 'シーズンポータル' },
      },
      {
        path: '/teams/:teamId/roster',
        name: 'SeasonRoster',
        component: () => import('@/views/ActiveRoster.vue'),
        meta: { requiresAuth: true, title: '出場選手登録' },
      },
      {
        path: '/teams/:teamId/season/games/:scheduleId',
        name: 'GameResult',
        component: () => import('@/views/GameResult.vue'),
        meta: { requiresAuth: true, title: '試合結果入力' },
      },
      {
        path: '/teams/:teamId/season/games/:scheduleId/scoresheet',
        name: 'ScoreSheet',
        component: () => import('@/views/ScoreSheet.vue'),
        meta: { requiresAuth: true, title: 'スコアシート' },
      },
      {
        path: '/teams/:teamId/season/player_absences',
        name: 'PlayerAbsenceHistory',
        component: () => import('@/views/PlayerAbsenceHistory.vue'),
        meta: { requiresAuth: true, title: '離脱者履歴' },
      },
      {
        path: '/games',
        name: '試合記録',
        component: () => import('@/views/GamesView.vue'),
        meta: { requiresAuth: true, title: '試合記録' },
      },
      {
        path: '/games/import',
        name: 'ログ取り込み',
        component: () => import('@/views/GameImportView.vue'),
        meta: { requiresAuth: true, title: 'IRCログ取り込み' },
      },
      {
        path: '/games/:id',
        name: '試合詳細',
        component: () => import('@/views/GameDetailView.vue'),
        meta: { requiresAuth: true, title: '試合詳細' },
        props: true,
      },
      {
        path: '/stats',
        name: '成績集計',
        component: () => import('@/views/StatsView.vue'),
        meta: { requiresAuth: true, title: '成績集計' },
      },
    ],
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/menu',
  },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
})

// 認証ガードを適用
router.beforeEach(authGuard)

export default router
