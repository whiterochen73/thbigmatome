import { onScopeDispose, shallowRef, toValue, watchEffect, type MaybeRefOrGetter } from 'vue'
import type { RouteLocationRaw } from 'vue-router'

/** 戻り先。行き先は固定の router-link（router.back() は使わない） */
export interface AppBarBack {
  to: RouteLocationRaw
  label: string
}

/** ヘッダーバー（AppBar）に出す画面のタイトル。h1 はバーが描く */
export interface AppBarTitle {
  title: string
  subtitle?: string | null
  back?: AppBarBack | null
}

/** 画面が宣言したタイトル。無い時は AppBar が route.meta.title を出す */
export const appBarTitle = shallowRef<AppBarTitle | null>(null)

/**
 * AppBar が実際に出している文字（画面の宣言か route.meta.title）。
 * まだ移していない画面の PageHeader が、バーと二重にならないよう見る。
 * AppBar が無い場所（単体テストなど）では空のままで、PageHeader は従来どおり自分で出す
 */
export const appBarShownTitle = shallowRef<string>('')

let currentOwner: symbol | null = null

export function setAppBarTitle(owner: symbol, value: AppBarTitle) {
  currentOwner = owner
  appBarTitle.value = value
}

export function clearAppBarTitle(owner: symbol) {
  // 新しい画面が先に登録していたら、古い画面の解除で消さない
  if (currentOwner !== owner) return
  currentOwner = null
  appBarTitle.value = null
}

/**
 * 画面のタイトルをバーへ渡す。source が null の間は宣言しない（route.meta.title が出る）。
 * 画面を離れる（スコープが閉じる）時に自動で解除する
 */
export function useAppBarTitle(source: MaybeRefOrGetter<AppBarTitle | null>) {
  const owner = Symbol('app-bar-title')
  watchEffect(() => {
    const value = toValue(source)
    if (value) setAppBarTitle(owner, value)
    else clearAppBarTitle(owner)
  })
  onScopeDispose(() => clearAppBarTitle(owner))
}
