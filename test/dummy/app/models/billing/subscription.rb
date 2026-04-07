class Billing::Subscription < ApplicationRecord
  self.table_name = "billing_subscriptions"
  belongs_to :team
  belongs_to :provider_subscription, polymorphic: true

  def included_prices
    Billing::IncludedPrice.where(subscription_id: id)
  end
end
