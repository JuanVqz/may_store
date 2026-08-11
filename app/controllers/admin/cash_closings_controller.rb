# The daily cash count: what the payments say the drawer should hold, against
# what was physically counted.
#
# Lives under Admin because that is its default screen. It is not restricted:
# every role can reach it, the same as the rest of the app.
class Admin::CashClosingsController < Admin::BaseController
  before_action :set_cash_closing, only: [:show, :update]

  def index
    @pagy, @cash_closings = pagy(Current.store.cash_closings.recent.includes(:user, :cash_closing_lines))
  end

  def show
  end

  # Reuses the day's open corte rather than starting a rival count of the same
  # money, and refreshes the expected totals so a corte opened at noon and
  # finished at close reflects the whole day.
  def create
    closing = CashClosing.open_for_today!(store: Current.store, user: Current.user)

    redirect_to admin_cash_closing_path(closing)
  end

  def update
    if @cash_closing.closed?
      redirect_to admin_cash_closing_path(@cash_closing), alert: t("admin.cash_closings.already_closed")
      return
    end

    if @cash_closing.update(cash_closing_params)
      close_and_redirect
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_cash_closing
    @cash_closing = Current.store.cash_closings.includes(cash_closing_lines: :payment_method).find(params[:id])
  end

  # Counted amounts arrive in pesos, which is what the cashier is holding;
  # PriceCents converts them to the integer cents the column stores.
  def cash_closing_params
    params.expect(cash_closing: [:notes, { cash_closing_lines_attributes: [[:id, :actual]] }])
  end

  # Saving the counts and closing the corte are the same form with two buttons,
  # so an admin can save a partial count and come back to it.
  def close_and_redirect
    if params[:close].present?
      @cash_closing.close!
      redirect_to admin_cash_closing_path(@cash_closing), notice: t("cash_closing.closed")
    else
      redirect_to admin_cash_closing_path(@cash_closing), notice: t("admin.cash_closings.saved")
    end
  end
end
