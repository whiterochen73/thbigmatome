import { shallowRef } from 'vue'
import type { RouteLocationRaw } from 'vue-router'

export interface AppBarBreadcrumbs {
  seasonPortalRoute: RouteLocationRaw
  teamName: string
  gameNumber: number | null
  date: string
}

export const appBarBreadcrumbs = shallowRef<AppBarBreadcrumbs | null>(null)

let currentOwner: symbol | null = null

export function setAppBarBreadcrumbs(owner: symbol, breadcrumbs: AppBarBreadcrumbs) {
  currentOwner = owner
  appBarBreadcrumbs.value = breadcrumbs
}

export function clearAppBarBreadcrumbs(owner: symbol) {
  if (currentOwner !== owner) return
  currentOwner = null
  appBarBreadcrumbs.value = null
}
