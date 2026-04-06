require "test_helper"

class UpdateIncludedPricesTest < ActiveSupport::TestCase
  setup do
    @team = Team.create!(name: "Test Team")
    @product = Billing::Product.create!(name: "Pro Plan")
    @price = Billing::Price.create!(product: @product, stripe_price_id: "price_abc123", trial_days: 0)

    @stripe_sub = Billing::Stripe::Subscription.create!(team: @team)
    @generic_sub = Billing::Subscription.create!(
      provider_subscription: @stripe_sub,
      team: @team,
      status: 0
    )
  end

  test "creates included price on first sync" do
    items = [{"price" => {"id" => "price_abc123"}, "quantity" => 5}]

    assert_difference "Billing::IncludedPrice.count", 1 do
      @stripe_sub.update_included_prices(items)
    end

    assert_equal 5, Billing::IncludedPrice.last.quantity
  end

  test "updates quantity on subsequent sync" do
    items_v1 = [{"price" => {"id" => "price_abc123"}, "quantity" => 5}]
    @stripe_sub.update_included_prices(items_v1)

    items_v2 = [{"price" => {"id" => "price_abc123"}, "quantity" => 10}]

    assert_no_difference "Billing::IncludedPrice.count" do
      @stripe_sub.update_included_prices(items_v2)
    end

    assert_equal 10, Billing::IncludedPrice.last.quantity
  end

  test "skips save when quantity unchanged" do
    items = [{"price" => {"id" => "price_abc123"}, "quantity" => 5}]
    @stripe_sub.update_included_prices(items)

    included_price = Billing::IncludedPrice.last
    original_updated_at = included_price.updated_at

    travel 1.second do
      @stripe_sub.update_included_prices(items)
    end

    assert_equal original_updated_at, included_price.reload.updated_at
  end

  test "removes prices no longer on the Stripe subscription" do
    items = [{"price" => {"id" => "price_abc123"}, "quantity" => 1}]
    @stripe_sub.update_included_prices(items)
    assert_equal 1, Billing::IncludedPrice.count

    @stripe_sub.update_included_prices([])
    assert_equal 0, Billing::IncludedPrice.count
  end
end
