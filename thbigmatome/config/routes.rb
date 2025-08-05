Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  namespace :api do
    namespace :v1 do
      # API のルートをここに定義
      # 認証関連
      post 'auth/login', to: 'auth#login'
      post 'auth/logout', to: 'auth#logout'
      get 'auth/current_user', to: 'auth#show_current_user'

      # 監督一覧
      resources :managers do
        resources :teams, only: [:index, :create]
      end
      # チーム一覧
      resources :teams, only: [:index, :show, :update, :create, :destroy]

      # 選手一覧
      resources :players, only: [:index, :show, :create, :update, :destroy]

      # 各種設定マスタ
      resources :player_types, path: 'player-types', only: [:index, :create, :update, :destroy]
      resources :pitching_styles, path: 'pitching-styles', only: [:index, :create, :update, :destroy]
      resources :pitching_skills, path: 'pitching-skills', only: [:index, :create, :update, :destroy]
      resources :batting_styles, path: 'batting-styles', only: [:index, :create, :update, :destroy]
      resources :batting_skills, path: 'batting-skills', only: [:index, :create, :update, :destroy]
      resources :biorhythms, only: [:index, :create, :update, :destroy]
      resources :costs, only: [:index, :show, :create, :update, :destroy]

      # コストアサインメント
      resources :cost_assignments, only: [:index, :create]

      # ユーザー登録
      post 'users', to: 'users#create'
    end
  end
end
