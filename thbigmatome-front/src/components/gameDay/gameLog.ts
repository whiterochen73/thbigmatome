// 試合ログ（IRC のログの原文）の扱い。保存するだけで、内容の解析はしない。

// サーバ側（SeasonSchedule::GAME_LOG_MAX_BYTES）と同じ上限。文字数ではなく UTF-8 のバイト数で数える
export const GAME_LOG_MAX_BYTES = 1_048_576

// ファイルを読み込む前の安全弁。Shift_JIS などは UTF-8 にすると大きくなるので、上限より余裕を持たせる
export const GAME_LOG_FILE_READ_MAX_BYTES = 8 * 1024 * 1024

export const gameLogByteLength = (text: string): number => new TextEncoder().encode(text).length

export type GameLogDecodeResult = { ok: true; text: string } | { ok: false }

const tryDecode = (label: string, bytes: Uint8Array): string | null => {
  try {
    return new TextDecoder(label, { fatal: true }).decode(bytes)
  } catch {
    return null
  }
}

// ISO-2022-JP は ESC $ B / ESC $ @ / ESC $ ( D で日本語に切り替わる。7bit だけで書かれるので UTF-8 としても
// 「正しい」と判定されてしまい、そのまま UTF-8 で読むと文字化けする。この切り替えの印があれば先に試す
const hasIso2022JpEscape = (bytes: Uint8Array): boolean => {
  for (let i = 0; i + 2 < bytes.length; i++) {
    if (bytes[i] !== 0x1b || bytes[i + 1] !== 0x24) continue
    const c = bytes[i + 2]
    if (c === 0x40 || c === 0x42) return true
    if (c === 0x28 && bytes[i + 3] === 0x44) return true
  }
  return false
}

// UTF-8 → Shift_JIS → ISO-2022-JP の順に、エラーなく読めた最初のもので読む（先頭の BOM は読み飛ばされる）
export const decodeGameLogBytes = (bytes: Uint8Array): GameLogDecodeResult => {
  const order = hasIso2022JpEscape(bytes)
    ? ['iso-2022-jp', 'utf-8', 'shift_jis']
    : ['utf-8', 'shift_jis', 'iso-2022-jp']
  for (const label of order) {
    const text = tryDecode(label, bytes)
    if (text !== null) return { ok: true, text }
  }
  return { ok: false }
}
