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

  # An open corte runs to "now", so viewing it moves its end forward and takes a
  # fresh reading. The screen exists to check a physical count against that
  # number, and a stale one sends someone hunting a difference that is not there.
  #
  # A write on a GET, but an idempotent one over derived columns, and
  # refresh_expected! leaves a closed corte alone: that is a record of a moment.
  def show
    @cash_closing.refresh_expected!
  end

  # Opens the corte that runs from the last closed one up to now, or reuses the
  # open one if there already is one: two open cortes would overlap and count the
  # same money twice.
  def create
    closing = CashClosing.open_current!(store: Current.store, user: Current.user)

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
