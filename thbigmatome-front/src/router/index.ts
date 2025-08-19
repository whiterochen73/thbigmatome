// src/router/index.ts
import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { authGuard } from './authGuard'
import LoginForm from '@/views/LoginForm.vue'
import DefaultLayout from '@/layouts/DefaultLayout.vue'
import TopMenu from '@/views/TopMenu.vue'
import ManagerList from '@/views/ManagerList.vue'
import TeamList from '@/views/TeamList.vue'
import Players from '@/views/Players.vue'
import CostAssignment from '@/views/CostAssignment.vue'
import TeamMembers from '@/views/TeamMembers.vue'


import Settings from '@/views/Settings.vue'

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'Login',
    component: LoginForm,
    meta: { requiresAuth: false }
  },
  {
    path: '/',
    component: DefaultLayout,
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        redirect: '/menu'
      },
      {
        path: 'menu',
        name: 'ダッシュボード',
        component: TopMenu,
        meta: { title: 'ダッシュボード' }
      },
      {
        path: 'managers',
        name: '監督一覧',
        component: ManagerList,
        meta: { title: '監督一覧' }
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
        meta: { requiresAuth: true, title: '選手一覧' }
      },
      {
        path: '/cost_assignment',
        name: 'CostAssignment',
        component: CostAssignment,
        meta: { requiresAuth: true, title: 'コスト登録' }
      },
      {
        path: 'settings',
        name: '各種設定',
        component: Settings,
        meta: { title: '各種設定' }
      },
      {
        path: '/teams/:teamId/season',
        name: 'SeasonPortal',
        component: () => import('@/views/SeasonPortal.vue'),
        meta: { requiresAuth: true, title: 'シーズンポータル' }
      },
      {
        path: '/teams/:teamId/roster',
        name: 'SeasonRoster',
        component: () => import('@/views/ActiveRoster.vue'),
        meta: { requiresAuth: true, title: '出場選手登録' }
      },
      {
        path: '/teams/:teamId/season/games/:scheduleId',
        name: 'GameResult',
        component: () => import('@/views/GameResult.vue'),
        meta: { requiresAuth: true, title: '試合結果入力' }
      }
    ]
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/menu'
  },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes
})

// 認証ガードを適用
router.beforeEach(authGuard)

export default router
