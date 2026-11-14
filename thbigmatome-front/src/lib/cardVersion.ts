// 同じ選手の別のカードを見分ける印（cmd_1901）。
// サーバが返す version_label（variant があればそれ、無ければ帯のチーム名・印）を使う。
// 古いレスポンスや variant だけを持つデータでも同じ結果になるよう、variant にもフォールバックする。
// 帯が GLADIATS の通常カードは印が無く null。

export interface CardVersionSource {
  variant?: string | null
  version_label?: string | null
}

export function cardVersionLabel(card: CardVersionSource | null | undefined): string | null {
  if (!card) return null
  return card.version_label?.trim() || card.variant?.trim() || null
}

// 「PM2027 / 飯能」。印が無ければカードセット名だけ
export function cardVersionText(
  cardSetName: string,
  card: CardVersionSource | null | undefined,
): string {
  const label = cardVersionLabel(card)
  return label ? `${cardSetName} / ${label}` : cardSetName
}
