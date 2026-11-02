import { useDisplay } from 'vuetify'

// 横スクロールのまま残す表（縦積みにしない表）の列の最小幅。
// 画面が Vuetify 4 の lg（1145px）未満の時だけ効かせる。それ以上では指定せず、これまでどおり列を詰めて収める（PC で不要な横スクロールを出さない）
export function useColumnMinWidth() {
  const { mdAndDown } = useDisplay()
  return (px: number): number | undefined => (mdAndDown.value ? px : undefined)
}
