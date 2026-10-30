import { describe, it, expect } from 'vitest'
import {
  GAME_LOG_MAX_BYTES,
  gameLogByteLength,
  decodeGameLogBytes,
} from '@/components/gameDay/gameLog'

// Test Basis: cmd_1783 subtask_1783j 要望 2（試合ログ。UTF-8 → Shift_JIS → ISO-2022-JP の順に読む。上限 1MB はバイト数）
const bytes = (...n: number[]) => new Uint8Array(n)

describe('gameLog', () => {
  describe('gameLogByteLength / 上限', () => {
    it('上限は 1_048_576 バイト（サーバ側と同じ）', () => {
      expect(GAME_LOG_MAX_BYTES).toBe(1_048_576)
    })

    it('文字数ではなく UTF-8 のバイト数で数える', () => {
      expect(gameLogByteLength('')).toBe(0)
      expect(gameLogByteLength('abc')).toBe(3)
      expect(gameLogByteLength('試合')).toBe(6)
      expect(gameLogByteLength('😀')).toBe(4)
    })
  })

  describe('decodeGameLogBytes', () => {
    it('UTF-8 はそのまま読む（BOM は読み飛ばす）', () => {
      expect(decodeGameLogBytes(new TextEncoder().encode('[21:30] 試合開始'))).toEqual({
        ok: true,
        text: '[21:30] 試合開始',
      })
      expect(decodeGameLogBytes(bytes(0xef, 0xbb, 0xbf, 0x61))).toEqual({ ok: true, text: 'a' })
    })

    it('空のファイルは空文字として読める', () => {
      expect(decodeGameLogBytes(bytes())).toEqual({ ok: true, text: '' })
    })

    it('UTF-8 として読めなければ Shift_JIS で読む', () => {
      // 試合開始
      expect(decodeGameLogBytes(bytes(142, 142, 141, 135, 138, 74, 142, 110))).toEqual({
        ok: true,
        text: '試合開始',
      })
    })

    it('ISO-2022-JP（ESC $ B で日本語に切り替わる）は、7bit だけで UTF-8 にも見えるが ISO-2022-JP で読む', () => {
      // 試合開始（ESC $ B ... ESC ( B）
      const jis = bytes(27, 36, 66, 59, 110, 57, 103, 51, 43, 59, 79, 27, 40, 66)
      expect(decodeGameLogBytes(jis)).toEqual({ ok: true, text: '試合開始' })
      // 英数字の前後にあっても同じ
      const mixed = new Uint8Array([0x61, 0x20, ...jis, 0x20, 0x62])
      expect(decodeGameLogBytes(mixed)).toEqual({ ok: true, text: 'a 試合開始 b' })
    })

    it('ESC があっても日本語への切り替えでなければ、通常どおり UTF-8 で読む', () => {
      // ESC [ 0 m（色指定）は日本語への切り替えではない
      expect(decodeGameLogBytes(bytes(0x1b, 0x5b, 0x30, 0x6d, 0x61))).toEqual({
        ok: true,
        text: '\u001b[0ma',
      })
    })

    it('どの文字コードでも読めなければ失敗を返す', () => {
      expect(decodeGameLogBytes(bytes(0x81, 0x20, 0xff))).toEqual({ ok: false })
    })
  })
})
