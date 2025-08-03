// src/router/index.ts
import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { authGuard } from './authGuard'
import LoginForm from '@/views/LoginForm.vue'
import DefaultLayout from '@/layouts/DefaultLayout.vue'
import TopMenu from '@/views/TopMenu.vue'
import ManagerList from '@/views/ManagerList.vue'
import TeamList from '@/views/TeamList.vue'
import Players from '@/views/Players.vue'

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
        path: 'teams',
        name: 'チーム一覧',
        component: TeamList,
        meta: { title: 'チーム一覧' }
      },
      {
        path: '/players',
        name: 'Players',
        component: Players,
        meta: { requiresAuth: true, title: '選手一覧' }
      },
      {
        path: 'settings',
        name: '各種設定',
        component: Settings,
        meta: { title: '各種設定' }
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
