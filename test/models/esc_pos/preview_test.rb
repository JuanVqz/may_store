require "test_helper"

class EscPos::PreviewTest < ActiveSupport::TestCase
  test "decodes CP437 back to readable text" do
    assert_equal "Café ñ ¡Qué!", preview { |d| d.text "Café ñ ¡Qué!" }
  end

  test "centres what the printer would centre" do
    text = preview { |d| d.center { d.text "TOTAL" } }

    assert_equal "TOTAL".center(EscPos::Document::COLUMNS).rstrip, text
  end

  test "centres double-width text within half the columns" do
    text = preview { |d| d.center { d.double_size { d.text "VIANDANTE" } } }

    assert_equal "VIANDANTE".center(EscPos::Document::COLUMNS / 2).rstrip, text
  end

  test "keeps blank lines so spacing survives" do
    text = preview { |d| d.text "a"; d.feed; d.text "b" }

    assert_equal ["a", "", "b"], text.split("\n", -1)
  end

  test "names the barcode payload instead of dumping its bytes" do
    assert_includes preview { |d| d.barcode "CFE2608-002" }, "[ codigo de barras: CFE2608-002 ]"
  end

  test "reports an image by size and skips its raster data" do
    raster = "\x00".b * (64 * 8)
    text = preview do |d|
      d.raw "\x1dv0\x00" + [64, 0, 8, 0].pack("C4") + raster
      d.text "after"
    end

    assert_includes text, "[ imagen 512x8 ]"
    assert_includes text, "after"
    assert_not_includes text, "\x00"
  end

  test "marks the cut" do
    assert_includes preview { |d| d.cut }, "corte"
  end

  test "a marker never overtakes the text before it" do
    text = preview { |d| d.center { d.text "Gracias"; d.barcode "ABC" } }
    lines = text.split("\n")

    assert_operator lines.index { |l| l.include?("Gracias") }, :<,
                    lines.index { |l| l.include?("codigo de barras") }
  end

  private

  def preview(&block)
    EscPos::Preview.new(EscPos::Document.new.build(&block).to_s).to_text
  end
end
