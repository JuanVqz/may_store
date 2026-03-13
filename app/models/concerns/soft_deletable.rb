module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(deleted_at: nil) }
    scope :deleted, -> { where.not(deleted_at: nil) }
  end

  def soft_delete!
    update_columns(deleted_at: Time.current)
  end

  def restore!
    update_columns(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end
end
