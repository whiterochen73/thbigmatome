FactoryBot.define do
  factory :team_manager do
    team
    manager
    role { :director }
  end
end
