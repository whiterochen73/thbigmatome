# 東方BIG野球まとめ

モノレポ構成: バックエンド (thbigmatome) + フロントエンド (thbigmatome-front)

## セットアップ

### 1. 依存ツールのインストール

```bash
# ルートディレクトリでlefthookをインストール
npm install

# バックエンド依存
cd thbigmatome
bundle install

# フロントエンド依存
cd ../thbigmatome-front
npm install
```

### 2. Git Hooks (Pre-commit)

プロジェクトにはlefthookを使った自動コード整形が設定されています。

**自動で実行されるもの:**
- Ruby (.rb) → `rubocop -a` (auto-fix)
- JS/TS/Vue (.js, .ts, .vue) → `eslint --fix` + `prettier --write`

**インストール:**
```bash
# ルートディレクトリで npm install を実行すると自動でインストールされます
npm install

# 手動でインストールする場合
npx lefthook install
```

**動作確認:**
```bash
# git commitすると自動で実行されます
git add .
git commit -m "test"
```

**一時的にスキップする場合:**
```bash
# 環境変数で無効化
LEFTHOOK=0 git commit -m "skip hooks"
```

## ディレクトリ構成

```
/home/morinaga/projects/
├── thbigmatome/          # バックエンド (Ruby on Rails)
│   ├── app/
│   ├── config/
│   ├── Gemfile
│   └── .rubocop.yml
├── thbigmatome-front/    # フロントエンド (Vue.js + TypeScript)
│   ├── src/
│   ├── package.json
│   ├── eslint.config.ts
│   └── .prettierrc.json
├── docs/                 # 仕様書
├── lefthook.yml          # Git hooks設定
└── package.json          # ルート (lefthookのみ)
```
