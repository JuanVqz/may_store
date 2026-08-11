require "test_helper"

class EscPos::DocumentTest < ActiveSupport::TestCase
  test "starts with initialise and the CP437 code page" do
    assert_equal "\e@\et\x00".b, EscPos::Document.new.to_s
  end

  test "encodes accented Spanish as CP437 bytes, not UTF-8" do
    bytes = document { |d| d.text "Café ñ ¡Qué!" }

    # The printer's font is byte-indexed: é is one byte, 0x82, not two.
    assert_includes bytes, "Caf\x82 \xa4 \xadQu\x82!".b
    assert_not_includes bytes, "Café".b
  end

  test "replaces characters the code page cannot represent instead of raising" do
    bytes = document { |d| d.text "Matcha 🍵" }

    assert_includes bytes, "Matcha ?".b
  end

  test "row fills the full width with the value flush right" do
    bytes = document { |d| d.row "TOTAL", "$144.00" }

    assert_includes bytes, "TOTAL#{" " * 30}$144.00\n".b
  end

  test "row truncates an over-long label rather than wrapping it" do
    bytes = document { |d| d.row "A" * 60, "$1.00" }
    line = bytes.split("\n").last

    assert_equal EscPos::Document::COLUMNS, line.length
    assert line.end_with?("$1.00")
  end

  test "wrapped keeps the caller's leading indent on every line" do
    bytes = document { |d| d.wrapped "    Crema batida con mucho chocolate y fresas encima" }
    lines = bytes.split("\n")

    assert_operator lines.size, :>, 1
    lines.each { |line| assert line.start_with?("    "), "lost indent: #{line.inspect}" }
    lines.each { |line| assert_operator line.length, :<=, EscPos::Document::COLUMNS }
  end

  test "wrapped breaks on words and indents continuation lines" do
    bytes = document { |d| d.wrapped "Crepa de nutella con fresas y platano y crema batida" }
    lines = bytes.split("\n")

    assert_operator lines.size, :>, 1
    lines.each { |line| assert_operator line.length, :<=, EscPos::Document::COLUMNS }
    assert lines.last.start_with?("  ")
  end

  # The continuation width has to account for the indent as well as the lead,
  # otherwise this method emits lines the printer re-breaks flush left, losing
  # the nesting it exists to produce.
  test "wrapped keeps indented continuation lines inside the column width" do
    note = "  NOTAS: sin cebolla ni tomate ni lechuga pero si mucha salsa por favor"
    lines = document { |d| d.wrapped note, indent: "    " }.split("\n")

    assert_operator lines.size, :>, 1
    lines.each do |line|
      assert_operator line.length, :<=, EscPos::Document::COLUMNS, "too wide: #{line.inspect}"
    end
  end

  test "wrapped hard-splits a word longer than the width" do
    lines = document { |d| d.wrapped "  #{"A" * 60}" }.split("\n")

    assert_operator lines.size, :>, 1
    lines.each { |line| assert_operator line.length, :<=, EscPos::Document::COLUMNS }
  end

  # Double width halves the usable columns, and the printer breaks an over-long
  # heading mid-word without telling anyone.
  test "double-size text wraps at half the columns" do
    lines = document { |d| d.double_size { d.text "Cafeteria y Restaurante Delicias" } }.split("\n")

    assert_operator lines.size, :>, 1
    lines.each { |line| assert_operator line.length, :<=, EscPos::Document::COLUMNS / 2 }
  end

  test "normal-width text is left exactly as given" do
    assert_equal "=" * EscPos::Document::COLUMNS,
                 document { |d| d.rule "=" }.chomp
  end

  test "styles restore themselves after the block" do
    bytes = document { |d| d.bold { d.text "x" } }

    assert_equal "\eE\x01x\n\eE\x00".b, bytes.sub("\e@\et\x00".b, "")
  end

  test "cut feeds past the blade before cutting" do
    bytes = document { |d| d.cut }

    assert bytes.end_with?("\n\n\n\n\x1dVA\x00".b)
  end

  test "barcode drops characters CODE39 cannot encode" do
    bytes = document { |d| d.barcode "cfe2603-test1" }

    assert_includes bytes, "*CFE2603-TEST1*".b
  end

  test "barcode is skipped when nothing encodable is left" do
    assert_equal "", document { |d| d.barcode "***" }
  end

  private

  def document(&block)
    EscPos::Document.new.build(&block).to_s.sub("\e@\et\x00".b, "")
  end
end
