class Billing::Stripe::PriceAdapter
  def self.find_by_stripe_price_id(stripe_price_id)
    Billing::Price.find_by(stripe_price_id: stripe_price_id)
  end
end
