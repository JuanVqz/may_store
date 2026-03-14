class Spot < ApplicationRecord
  belongs_to :store
  has_many :orders

  enum :spot_type, { dine_in: "dine_in", takeout: "takeout" }

  validates :name, presence: true, uniqueness: { scope: :store_id }
  validates :spot_type, presence: true

  scope :tables, -> { where(spot_type: :dine_in) }
  scope :takeouts, -> { where(spot_type: :takeout) }

  def self.takeout_for(store)
    find_or_create_by!(store: store, spot_type: :takeout) do |spot|
      spot.name = I18n.t("spot_types.takeout")
    end
  end
end
