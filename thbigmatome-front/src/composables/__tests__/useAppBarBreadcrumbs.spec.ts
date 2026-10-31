import { describe, expect, it } from 'vitest'
import {
  appBarBreadcrumbs,
  clearAppBarBreadcrumbs,
  setAppBarBreadcrumbs,
} from '../useAppBarBreadcrumbs'

// Test Basis: subtask_1783q finding「owner 照合の変異が生存」
describe('useAppBarBreadcrumbs', () => {
  it('新ページの登録後に旧ページの解除が走っても、新ページのぱんくずを残す', () => {
    const oldOwner = Symbol('old-page')
    const newOwner = Symbol('new-page')
    const oldCrumbs = {
      seasonPortalRoute: '/season/1',
      teamName: '旧ページ',
      gameNumber: 1,
      date: '6月1日',
    }
    const newCrumbs = { ...oldCrumbs, teamName: '新ページ', gameNumber: 2 }

    setAppBarBreadcrumbs(oldOwner, oldCrumbs)
    setAppBarBreadcrumbs(newOwner, newCrumbs)
    clearAppBarBreadcrumbs(oldOwner)
    expect(appBarBreadcrumbs.value).toEqual(newCrumbs)

    clearAppBarBreadcrumbs(newOwner)
    expect(appBarBreadcrumbs.value).toBeNull()
  })
})
