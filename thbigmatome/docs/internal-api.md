# Dugout 内部API運用メモ

## 認証

内部APIは `X-Internal-Api-Key` ヘッダーで認証する。キーは `INTERNAL_API_KEY` 環境変数に設定する。

本番環境では開発用デフォルト値 `thbig-internal-sync-key` を使用しない。`openssl rand -hex 32` などで生成した強固な値を、Dugout本番と同期元サービスの両方に設定する。

## エクスポートAPI

対象:

- `GET /api/v1/internal/players`
- `GET /api/v1/internal/teams`
- `GET /api/v1/internal/stadiums`
- `GET /api/v1/internal/card_sets`
- `GET /api/v1/internal/player_cards`
- `GET /api/v1/internal/seasons`
- `GET /api/v1/internal/games`

`page` / `per_page` を指定しない場合は、従来互換の配列レスポンスを返す。

`page` または `per_page` を指定した場合は、ページングレスポンスを返す。

```json
{
  "players": [],
  "meta": {
    "current_page": 1,
    "per_page": 100,
    "total_count": 0,
    "total_pages": 0
  }
}
```

`per_page` の上限は `1000`。大量同期では `page=1&per_page=1000` から順に取得する。
