module Order::CodeGenerable
  extend ActiveSupport::Concern

  included do
    before_create :generate_code
  end

  private

  def generate_code
    return if code.present?

    prefix = store.order_prefix
    year_month = Time.current.strftime("%y%m")

    retries = 3
    begin
      OrderCounter.find_or_create_by!(store_id: store_id, year_month: year_month) do |c|
        c.current_sequence = 0
      end
    rescue ActiveRecord::RecordNotUnique
      retry if (retries -= 1) > 0
      raise
    end

    sql = OrderCounter.sanitize_sql_array([
      "UPDATE order_counters SET current_sequence = current_sequence + 1, updated_at = NOW() " \
      "WHERE store_id = ? AND year_month = ? RETURNING current_sequence",
      store_id, year_month
    ])
    seq = OrderCounter.connection.select_value(sql)

    self.code = "#{prefix}#{year_month}-#{seq.to_s.rjust(3, '0')}"
  end
end
