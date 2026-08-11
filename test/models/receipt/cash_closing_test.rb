require "test_helper"

class Receipt::CashClosingTest < ActiveSupport::TestCase
  setup do
    @closing = cash_closings(:open_closing)
  end

  test "prints the store, period and who counted" do
    text = printable(@closing)

    assert_includes text, @closing.store.name
    assert_includes text, @closing.user.name
    assert_includes text, I18n.t("cash_closing.title")
  end

  test "prints a block per payment method rather than four columns in a row" do
    text = printable(@closing)

    @closing.cash_closing_lines.each do |line|
      assert_includes text, line.payment_method.name.upcase
    end
    assert_includes text, I18n.t("cash_closing.expected")
    assert_includes text, I18n.t("cash_closing.actual")
  end

  # The whole reason for the per-method block: four money columns do not fit.
  test "no line exceeds the paper width" do
    printable(@closing).split("\n").each do |line|
      assert_operator line.length, :<=, EscPos::Document::COLUMNS, "too wide: #{line.inspect}"
    end
  end

  test "signs a shortfall and a surplus explicitly" do
    line = @closing.cash_closing_lines.first
    line.update!(expected_cents: 10_000, actual_cents: 9_500)

    assert_includes printable(@closing.reload), "-$5.00"

    line.update!(actual_cents: 10_500)

    assert_includes printable(@closing.reload), "+$5.00"
  end

  test "a matching count prints as zero with no sign" do
    @closing.cash_closing_lines.each { |line| line.update!(expected_cents: 5_000, actual_cents: 5_000) }

    text = printable(@closing.reload)

    assert_includes text, "$0.00"
    assert_not_includes text, "+$0.00"
  end

  test "prints notes when present" do
    @closing.update!(notes: "faltaron cincuenta pesos en efectivo")

    assert_includes printable(@closing), "faltaron cincuenta pesos en efectivo"
  end

  test "leaves somewhere to sign" do
    assert_includes printable(@closing), I18n.t("cash_closing.signature")
  end

  test "ends with a cut" do
    assert Receipt::CashClosing.new(@closing).to_escpos.end_with?("\x1dVA\x00".b)
  end

  private

  def printable(closing)
    EscPos::Preview.new(Receipt::CashClosing.new(closing).to_escpos).to_text
  end
end
