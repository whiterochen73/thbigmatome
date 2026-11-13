# PM2027 の構造化データ

東方BIG野球のオリジナル選手カード「PM2027」（144 枚・16 ページ × 9）を、PM2026 と並べて取り込むための入力。
`PM2027.pdf` の文字層から作った（2026-11-13、PM2026 との差分調査 cmd_1890 / subtask_1890a）。PDF 自体は repo に置いていない。

CSV 行は `scripts/generate_pm2027_cards.rb` がこのディレクトリと現行の PM2026 の CSV 行から作り、`db/import/*.csv` の末尾に足す（card_seq 433〜576、出典 `PM2027`）。手で行を書かない。

```
cd thbigmatome
ruby scripts/generate_pm2027_cards.rb            # PM2027 の行を作り直して 5 本の CSV の末尾に書く（何度流しても同じ）
ruby scripts/generate_pm2027_cards.rb --report   # 書かずに、変更の適用・語彙に無い記述・けがの空欄を一覧する
```

## ファイル

| ファイル | 中身 |
|---|---|
| `PM2027_cards.json` | 144 枚の構造化データ。ページ・位置・背番号・位置名・版の印字・打撃表 20×5・投球表・走力・盗塁・バント・守備・けが・疲労 P・特徴行・注記行。`idx` は 0 始まりの通し番号（`(ページ-1)*9 + 行*3 + 列`。card_seq は `433 + idx`） |
| `pm2027_diff_summary.json` | PM2026 との対応表。`matches` は「PM2027 の idx → PM2026 の card_seq」（129 枚）、`added`（15 枚）、`deleted`（6 枚）、`content_changed`（6 枚） |
| `pm2027_changes_curated.json` | 変更 6 枚の項目ごとの対（PM2026 の画像・PM2026 の CSV・PM2027）。生成スクリプトが「現行 CSV が PM2026 側の値と一致する」ことを確かめてから PM2027 側を当てる |
| `csvgap.json` | PM2027 と PM2026 の画像が一致し、CSV だけが違った項目（331・332 の名前・位置の空欄、397・407 の登板時守備など）。読み直し（cmd_1888・1892）で CSV 側は直した。参考 |
| `pm2027_raw.json` | PDF の単語座標から切り出した、1 枚ごとの生の行・マス |

## 作り方の要点

- 一致した 129 枚は PM2026 の CSV 行を写して card_seq と出典だけ変える（読み直しで直した値を失わない）。変更 6 枚は差分を当てる。321 你 藍翠 は PM2027 では投手カードなので JSON から作り直す
- 新規 15 枚は JSON から CSV の語彙で作る。語彙に無い記述は定義を作らず `unique_traits` に生テキストで残す（`--report` の `UNKNOWN`）
- PDF にけがの数字が印字されていないカード（9 枚）は、PM2026 の CSV が 7 のため、新規の 蓬莱山 輝夜（零輝）も 7 にした
- 差分調査の本文は `context/thbig-pm2027-diff.md`（ハーネス側）
