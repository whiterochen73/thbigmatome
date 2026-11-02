namespace :e2e do
  desc "e2e（thbigmatome-front/e2e）用の前提データを入れる。test 環境だけで動く（何度流しても同じ結果）"
  task seed: :environment do
    # testuser / testpassword を作るので、本番や開発の DB には絶対に流さない
    abort "e2e:seed は RAILS_ENV=test の時だけ動きます（今は #{Rails.env}）" unless Rails.env.test?

    load Rails.root.join("db/seeds/test.rb")
  end
end
