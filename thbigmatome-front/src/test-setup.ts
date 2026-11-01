import { afterEach } from 'vitest'

// Test setup for Vitest
// Mock visualViewport which is not available in happy-dom
if (!window.visualViewport) {
  Object.defineProperty(window, 'visualViewport', {
    value: {
      width: 1024,
      height: 768,
      scale: 1,
      offsetLeft: 0,
      offsetTop: 0,
      pageLeft: 0,
      pageTop: 0,
      addEventListener: () => {},
      removeEventListener: () => {},
    },
    writable: true,
  })
}

// vue-i18n など dev ビルドの Vue プラグインは、devtools が無いと __VUE_DEVTOOLS_PLUGINS__ に app を積む。
// 積まれた app は unmount しても解放されず、マウントごとに数 MB ずつヒープが膨らむ（GameResult.spec は 224 件で約 3GB。
// 負荷がかかると GC で 5000ms を超え、時間切れが毎回別のテストで出た）。テストごとに空にして app を手放す
afterEach(() => {
  const target = globalThis as { __VUE_DEVTOOLS_PLUGINS__?: unknown[] }
  if (Array.isArray(target.__VUE_DEVTOOLS_PLUGINS__)) target.__VUE_DEVTOOLS_PLUGINS__.length = 0
})

// Vue のイベントハンドラは「リスナーを付けた時刻（ms）以前のイベント」を無視する（runtime-dom の invoker.attached と
// e._vts の比較。どちらも Date.now() で、attached は同じ tick の間キャッシュされる）。WSL2 では時計が数百 ms 戻ることがあり
// （Date.now() を連続で呼ぶと約 30 秒ごとに -500〜-750ms を実測）、戻った後は付けたばかりのハンドラの attached が
// 「未来」になって click / input が黙って無視される。GameResult.spec で毎回別のテストが落ちた原因。
// 実ブラウザでは起きないので、テストでは Date.now() が戻らないようにする（戻った分は実時間が追いつくまで止まる）
const realDateNow = Date.now.bind(Date)
let lastDateNow = 0
Date.now = () => {
  lastDateNow = Math.max(lastDateNow, realDateNow())
  return lastDateNow
}
