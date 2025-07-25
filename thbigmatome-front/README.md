# thbigmatome-front

## 概要

このプロジェクトは `thbigmatome` のフロントエンドアプリケーションです。
Vue.jsとViteで構築されています。

## 主な技術スタック

- Vue 3
- Vite
- TypeScript
- Vuetify
- Pinia
- Vue Router

## 開発環境のセットアップ

### 前提条件

- Node.js (18.x or later)
- npm, yarn, or pnpm

### 手順

1.  **リポジトリをクローンします**
    ```bash
    git clone <repository_url>
    cd thbigmatome-front
    ```

2.  **環境変数を設定します**
    `.env.example` をコピーして `.env.local` ファイルを作成し、バックエンドAPIのURLを設定します。
    ```bash
    cp .env.example .env.local
    ```
    必要に応じて `.env.local` の `VITE_API_BASE_URL` を編集してください。

    **注意:** `.env.local` ファイルは `.gitignore` に含まれており、リポジトリにはコミットされません。

3.  **依存関係をインストールします**
    ```bash
    npm install
    # or: yarn install
    # or: pnpm install
    ```

4.  **開発サーバーを起動します**
    ```bash
    npm run dev
    # or: yarn dev
    # or: pnpm dev
    ```
    アプリケーションは `http://localhost:5173` (Viteのデフォルト) で利用可能になります。

## ビルド

本番用のファイルを生成するには、以下のコマンドを実行します。

```bash
npm run build
```
ビルドされたファイルは `dist` ディレクトリに出力されます。