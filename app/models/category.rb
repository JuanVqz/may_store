class Category < ApplicationRecord
  include SoftDeletable

  belongs_to :store
  has_many :products

  # Which prep area the kitchen queue files this category's products under.
  enum :station, {
    kitchen: "kitchen",
    bar: "bar"
  }, prefix: true

  validates :name, presence: true
  validates :station, presence: true

  scope :ordered, -> { order(:position) }

  def station_label
    I18n.t("stations.#{station}")
  end
end
