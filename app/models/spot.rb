class Spot < ApplicationRecord
  belongs_to :store
  has_many :orders, dependent: :restrict_with_error

  enum :spot_type, { dine_in: "dine_in", takeout: "takeout" }

  validates :name, presence: true, uniqueness: { scope: :store_id }
  validates :spot_type, presence: true

  scope :tables, -> { where(spot_type: :dine_in) }
  scope :takeouts, -> { where(spot_type: :takeout) }
  scope :containing, ->(term) { where("name ILIKE ?", "%#{sanitize_sql_like(term)}%") }

  def self.takeout_for(store)
    retries = 3
    begin
      find_or_create_by!(store: store, spot_type: :takeout) do |spot|
        spot.name = I18n.t("spot_types.takeout")
      end
    rescue ActiveRecord::RecordNotUnique
      retry if (retries -= 1) > 0
      raise
    end
  end
end
