class User < ApplicationRecord
  include SoftDeletable

  belongs_to :store
  has_one :account, dependent: :destroy
  has_many :orders
  has_many :cash_closings

  enum :role, {
    waiter: "waiter",
    kitchen: "kitchen",
    admin: "admin"
  }

  normalizes :email, with: -> { it.strip.downcase }

  validates :name, presence: true
  validates :role, presence: true

  def role_label
    I18n.t("roles.#{role}")
  end
end
