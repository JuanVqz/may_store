class PaymentMethod < ApplicationRecord
  belongs_to :store
  # Both of these are backed by database foreign keys, so either one left
  # unguarded turns an admin delete into an InvalidForeignKey 500.
  has_many :payments, dependent: :restrict_with_error
  has_many :cash_closing_lines, dependent: :restrict_with_error

  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :containing, ->(term) { where("name ILIKE ?", "%#{sanitize_sql_like(term)}%") }
end
