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
      post "auth/login", to: "auth#login"
      post "auth/logout", to: "auth#logout"
      get "auth/current_user", to: "auth#show_current_user"

      # 監督一覧
      resources :managers
      # チーム一覧
      resources :teams, only: [ :index, :show, :update, :create, :destroy ] do
        resource :season, only: [ :show, :update ], controller: "team_seasons" do
          patch "season_schedules/:id", to: "team_seasons#update_season_schedule"
        end
        resource :roster, only: [ :show, :create ], controller: "team_rosters"
        resource :key_player, only: [ :create ], controller: "team_key_players"
        resources :team_players, only: [ :index, :create ]
        resources :team_memberships, only: [ :index ]
      end

      resources :game, only: [ :show, :update ]

      # 選手一覧
      resources :players, only: [ :index, :show, :create, :update, :destroy ]
      resources :team_registration_players, only: [ :index ]

      # 各種設定マスタ
      resources :card_sets, only: [ :index, :show ]
      resources :player_types, path: "player-types", only: [ :index, :create, :update, :destroy ]
      resources :pitching_styles, path: "pitching-styles", only: [ :index, :create, :update, :destroy ]
      resources :pitching_skills, path: "pitching-skills", only: [ :index, :create, :update, :destroy ]
      resources :batting_styles, path: "batting-styles", only: [ :index, :create, :update, :destroy ]
      resources :batting_skills, path: "batting-skills", only: [ :index, :create, :update, :destroy ]
      resources :biorhythms, only: [ :index, :create, :update, :destroy ]
      resources :costs, only: [ :index, :show, :create, :update, :destroy ] do
        post :duplicate, on: :member
      end

      # シーズンマスタ
      resources :seasons, only: [ :create ]
      resources :player_absences, only: [ :index, :create, :update, :destroy ]

      # 日程表マスタ
      resources :schedules, only: [ :index, :create, :update, :destroy ] do
        resources :schedule_details, only: [ :index ] do
          collection do
            post :upsert_all
          end
        end
      end

      # 大会管理
      resources :competitions, only: [ :index, :show, :create, :update, :destroy ]
      # 選手カード
      resources :player_cards, only: [ :index, :show ]

      # コストアサインメント
      resources :cost_assignments, only: [ :index, :create ]

      # 球場マスタ
      resources :stadiums, only: [ :index, :show, :create, :update ]

      # ユーザー管理（commissioner専用）
      resources :users, only: [ :index, :create ] do
        member do
          patch :reset_password
        end
      end

      namespace :commissioner do
        resources :leagues do
          resources :league_memberships, only: [ :index, :create, :destroy ]
          resources :league_seasons do
            post "generate_schedule", on: :member
            resources :league_games, only: [ :index, :show ]
            resources :league_pool_players, only: [ :index, :create, :destroy ]
          end
          resources :teams do
            resources :team_memberships, only: [ :index, :update, :destroy ] do
              resources :player_absences, only: [ :index, :create, :update, :destroy ]
            end
            resources :team_managers, only: [ :index, :create, :update, :destroy ]
          end
        end
      end
    end
  end
end
