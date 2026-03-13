require "test_helper"

class LineItemComponentTest < ActiveSupport::TestCase
  test "validates portion inclusion" do
    item = line_items(:ordering_americano)
    lic = LineItemComponent.new(line_item: item, component: components(:espresso_shot), component_type: :ingredient, portion: 0.33)
    assert_not lic.valid?
  end

  test "allows valid portions" do
    item = line_items(:ordering_americano)
    [0.0, 0.25, 0.5, 0.75, 1.0].each do |portion|
      lic = LineItemComponent.new(line_item: item, component: components(:espresso_shot), component_type: :ingredient, portion: portion, unit_price_cents: 0)
      assert lic.valid?, "Expected portion #{portion} to be valid"
    end
  end

  test "allows duplicate components (multiple extras)" do
    item = line_items(:ordering_americano)
    lic1 = LineItemComponent.create!(line_item: item, component: components(:extra_chocolate), component_type: :extra, portion: 1.0, unit_price_cents: 1000)
    lic2 = LineItemComponent.create!(line_item: item, component: components(:extra_chocolate), component_type: :extra, portion: 1.0, unit_price_cents: 1000)
    assert_not_equal lic1.id, lic2.id
  end

  test "portion_label returns i18n string" do
    item = line_items(:ordering_americano)
    lic = LineItemComponent.create!(line_item: item, component: components(:espresso_shot), component_type: :ingredient, portion: 0.5, unit_price_cents: 0)
    assert_equal I18n.t("portions.half"), lic.portion_label
  end
end
