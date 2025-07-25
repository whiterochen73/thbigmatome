# thbigmatome

## 概要

このプロジェクトは [ここにプロジェクトの簡単な説明を記述] のためのバックエンドAPIサーバーです。
Ruby on Railsで構築されています。

## 主な技術スタック

- Ruby on Rails 7.x
- PostgreSQL
- Puma
- Solid Queue
- Kamal (デプロイツール)

## 開発環境のセットアップ

### 前提条件

- Ruby (3.3.x)
- Bundler
- PostgreSQL
- Node.js
- Yarn

### 手順

1.  **リポジトリをクローンします**
    ```bash
    git clone <repository_url>
    cd thbigmatome
    ```

2.  **環境変数を設定します**
    `.env` ファイルをプロジェクトルートに作成し、必要な環境変数を設定します。
    データベースの認証情報やRailsの`master.key`を記述します。

    ```bash
    touch .env
    ```
    `.env`ファイルに以下のような内容を記述してください。
    ```
    DB_USERNAME=morinaga
    DB_PASSWORD=your_database_password
    RAILS_MASTER_KEY=... # config/master.keyの内容をコピー
    ```
    **注意:** `.env` ファイルは `.gitignore` に含まれており、リポジトリにはコミットされません。

3.  **依存関係をインストールします**
    ```bash
    bundle install
    yarn install
    ```

4.  **データベースをセットアップします**
    ```bash
    bin/rails db:create db:migrate
    ```

5.  **開発サーバーを起動します**
    ```bash
    bin/rails s
    ```
    サーバーは `http://localhost:3000` で起動します。

## テスト

以下のコマンドでテストスイートを実行します。

```bash
bin/rails test
```

## デプロイ

このプロジェクトは Kamal を使用してデプロイされます。
`config/deploy.yml` を環境に合わせて設定した後、以下のコマンドを実行します。

```bash
# 初回セットアップ
bin/kamal setup

# デプロイ
bin/kamal deploy
```