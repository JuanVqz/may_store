class Category < ApplicationRecord
  include SoftDeletable

  belongs_to :store
  has_many :products

  # Which prep area the kitchen queue files this category's products under.
  # `validate: true` so a station outside the enum fails validation instead of
  # raising ArgumentError on assignment, which a tampered or stale form post
  # would otherwise turn into a 500.
  enum :station, {
    kitchen: "kitchen",
    bar: "bar"
  }, prefix: true, validate: true

  validates :name, presence: true
  validates :station, presence: true

  scope :ordered, -> { order(:position) }

  def station_label
    I18n.t("stations.#{station}")
  end
end
