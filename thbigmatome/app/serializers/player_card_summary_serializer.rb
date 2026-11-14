class PlayerCardSummarySerializer < ActiveModel::Serializer
  attributes :id, :card_type, :handedness, :speed, :bunt,
             :injury_rate, :is_pitcher, :is_relief_only,
             :starter_stamina, :relief_stamina, :variant

  # belongs_to :card_set は選手詳細の下では AMS の既定の深さで落ちて card_set が出なかった（cmd_1902）。
  # 選手詳細は 1 画面で全カードを見せるので、セット名・版の印・画像をここで平らに返す。
  attribute :card_set do
    { id: object.card_set.id, name: object.card_set.name, is_current: object.card_set.is_current }
  end

  attribute :card_set_name do
    object.card_set.name
  end

  attribute :card_set_current do
    object.card_set.is_current
  end

  attribute :version_label do
    object.version_label
  end

  attribute :image_url do
    object.card_image_url
  end
end
