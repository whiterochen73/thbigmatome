import { reactive } from 'vue'
import axios from 'axios'
import type { DashboardResource } from '@/types/commissionerDashboard'

/**
 * ダッシュボードの 1 本の API（配列を返す GET）を、読み込み中・失敗つきで持つ。
 * API ごとに別々の状態にするので、遅い API が他の表示を待たせず、1 本の失敗が他へ及ばない。
 */
export function useDashboardResource<T>(url: string, label: string) {
  const state = reactive({ data: [] as T[], loading: true, failed: false }) as DashboardResource<T>

  const fetch = async () => {
    state.loading = true
    state.failed = false
    try {
      const response = await axios.get<T[]>(url)
      state.data = response.data
    } catch (error) {
      console.error(`Failed to fetch ${label}:`, error)
      state.failed = true
    } finally {
      state.loading = false
    }
  }

  return { state, fetch }
}
