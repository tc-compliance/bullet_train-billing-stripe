class Billing::Subscription < ApplicationRecord
  self.table_name = "billing_subscriptions"
  belongs_to :provider_subscription, polymorphic: true
  has_many :included_prices, class_name: "Billing::IncludedPrice", foreign_key: :subscription_id

  def included_prices
    Billing::IncludedPrice.where(subscription_id: id)
  end
end
