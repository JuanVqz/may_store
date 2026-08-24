require "test_helper"

# The admin lists all search the same way, through each model's `containing`
# scope. What is worth pinning is the part that is easy to get wrong: the term
# is a literal, not a pattern, so a stray % does not match the whole catalogue.
class SearchingTest < ActiveSupport::TestCase
  setup do
    @store = stores(:cafe_delicias)
  end

  test "categories match on part of the name, either case" do
    assert_includes @store.categories.containing("bebi"), categories(:bebidas_calientes)
    assert_includes @store.categories.containing("BEBI"), categories(:bebidas_calientes)
    assert_empty @store.categories.containing("zzz")
  end

  test "a wildcard typed into the box is searched for, not obeyed" do
    assert_empty @store.categories.containing("%")
    assert_empty @store.components.containing("_")
    assert_empty @store.spots.containing("%")
    assert_empty @store.payment_methods.containing("%")
    assert_empty @store.products.containing("%")
  end

  # A menu section is what someone is most often looking for, so a product
  # search answers to its category's name too.
  test "products match on their own name or on their category's" do
    crepa = products(:crepa_nutella)

    assert_includes @store.products.containing("nutella"), crepa
    assert_includes @store.products.containing(crepa.category.name), crepa
    assert_empty @store.products.containing("zzz")
  end
end
