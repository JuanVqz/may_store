class Spot < ApplicationRecord
  belongs_to :store
  has_many :orders, dependent: :restrict_with_error

  enum :spot_type, { dine_in: "dine_in", takeout: "takeout" }

  validates :name, presence: true, uniqueness: { scope: :store_id }
  validates :spot_type, presence: true

  scope :active, -> { where(active: true) }
  scope :tables, -> { where(spot_type: :dine_in) }
  scope :takeouts, -> { where(spot_type: :takeout) }
  scope :containing, ->(term) { where("name ILIKE ?", "%#{sanitize_sql_like(term)}%") }

  # A table holds one live order at a time, so tapping its card twice, or two
  # waiters tapping it at once, join the order already on the table instead of
  # opening a second bill for it. Only the first of those two orders was ever
  # reachable from the board, since it keys orders by spot; the other stayed
  # open, collectable from the day's list, and payable on its own.
  #
  # Takeout is the opposite by nature: several orders wait side by side, so a
  # tap there always starts a new one.
  #
  # The oldest live order wins, not whichever row comes back first: order ids
  # are uuids, so "first" would pick at random between the duplicates this rule
  # is here to stop, and the running bill is the one the guests have been adding
  # to.
  def open_order(user:)
    if dine_in? && (running = orders.in_progress.order(:created_at).first)
      running
    else
      orders.create!(store: store, user: user, status: :open, opened_at: Time.current)
    end
  end

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
