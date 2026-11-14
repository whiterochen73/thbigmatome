import { describe, it, expect } from 'vitest'
import { cardVersionLabel, cardVersionText } from '../cardVersion'

// Test Basis: Operator 指示（2026-11-14）「バリエーション選択の時、完走カードはチーム名で区別できるように。AP と被ることもある」
// 帯がチーム名のもの・印（エイプリル・UR など）・空（帯の名前を team_label に持つもの）・GLADIATS（印なし）・variant だけの古い形
describe('cardVersionLabel', () => {
  it('チーム名の帯（variant）はそのまま', () => {
    expect(cardVersionLabel({ variant: '飯能', version_label: '飯能' })).toBe('飯能')
  })
  it('チーム名でない印（エイプリル・UR・WBC2）はその印のまま', () => {
    expect(cardVersionLabel({ version_label: 'エイプリル' })).toBe('エイプリル')
    expect(cardVersionLabel({ version_label: 'UR' })).toBe('UR')
    expect(cardVersionLabel({ version_label: 'WBC2' })).toBe('WBC2')
  })
  it('variant が空で帯の名前だけある（サーバが version_label に帯の名前を入れる）', () => {
    expect(cardVersionLabel({ variant: null, version_label: '永山' })).toBe('永山')
  })
  it('GLADIATS の通常カードは印なし（null）', () => {
    expect(cardVersionLabel({ variant: null, version_label: null })).toBeNull()
    expect(cardVersionLabel({ variant: '', version_label: ' ' })).toBeNull()
  })
  it('version_label を持たない古い形は variant で見せる', () => {
    expect(cardVersionLabel({ variant: ' 湘南 ' })).toBe('湘南')
  })
  it('カードが無ければ null', () => {
    expect(cardVersionLabel(null)).toBeNull()
    expect(cardVersionLabel(undefined)).toBeNull()
  })
})

describe('cardVersionText', () => {
  it('セット名 / 印', () => {
    expect(cardVersionText('PM2027', { version_label: '筑紫野' })).toBe('PM2027 / 筑紫野')
  })
  it('印が無ければセット名だけ', () => {
    expect(cardVersionText('PM2027', { version_label: null })).toBe('PM2027')
    expect(cardVersionText('PM2027', null)).toBe('PM2027')
  })
})
