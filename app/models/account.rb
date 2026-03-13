class Account < ApplicationRecord
  belongs_to :user
  has_secure_password

  normalizes :employee_number, with: -> { it.strip.upcase }

  validates :employee_number, presence: true
  validates :user_id, uniqueness: true

  validate :employee_number_unique_in_store

  private

  def employee_number_unique_in_store
    existing = Account.joins(:user)
                      .where(users: { store_id: user.store_id })
                      .where(employee_number: employee_number)
                      .where.not(id: id)
    errors.add(:employee_number, :taken) if existing.exists?
  end
end
