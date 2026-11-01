// スマホ（<600px）の縦積み行で、列をどこに置くかを決める（PageLayout の CSS が class を読む）。
// 表に class="ui-table ui-table--rows" と mobile-breakpoint="sm" を付け、列の定義に cellProps を足す。
//   lead … 左の番号・画像 / title … 名前 / sub1・sub2 … 要点 / note … 補足 1 行（note2 を足すと同じ行の右隣に並ぶ） / act … 操作
// class の無い列は 600px 未満では出さない（PC の表は変わらない）。
// labeled … 列の見出しを値の前に小さく出す（開始日・終了日のように、値だけでは何か分からない列用）
const cell = (name: string, labeled = false) => ({
  class: `ui-cell ui-cell--${name}${labeled ? ' ui-cell--labeled' : ''}`,
})

export const tableCell = {
  lead: cell('lead'),
  title: cell('title'),
  sub1: cell('sub1'),
  sub2: cell('sub2'),
  note: cell('note'),
  sub1Labeled: cell('sub1', true),
  sub2Labeled: cell('sub2', true),
  noteLabeled: cell('note', true),
  // note と同じ行の右隣に並べる補足（note と一緒に使う）
  note2: cell('note2'),
  note2Labeled: cell('note2', true),
  act: cell('act'),
}
