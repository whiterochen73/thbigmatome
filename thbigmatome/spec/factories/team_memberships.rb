FactoryBot.define do
  factory :team_membership do
    team
    player
    squad { "second" }
    selected_cost_type { "normal_cost" }
    excluded_from_team_total { false }

    # 1軍/2軍は昇降格の変更記録（season_rosters）で決まる（RosterState。記録が無い選手は 2軍）。
    # first_since を渡すと、その日付（試合前）に 1軍へ昇格した記録を足す。チームにシーズンが要る。
    transient do
      first_since { nil }
    end

    after(:create) do |membership, evaluator|
      if evaluator.first_since
        season = membership.team.season or raise "first_since にはチームのシーズンが要る（先に create(:season, team: team) する）"
        create(:season_roster, season: season, team_membership: membership, squad: "first",
                               registered_on: evaluator.first_since, phase: "pre_game")
        membership.update_columns(squad: "first")
      end
    end

    trait :first_squad do
      squad { "first" }
    end

    trait :excluded do
      excluded_from_team_total { true }
    end
  end
end
