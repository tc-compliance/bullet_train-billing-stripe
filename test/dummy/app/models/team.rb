class Team < ApplicationRecord
  has_many :billing_stripe_subscriptions, class_name: "Billing::Stripe::Subscription"
end
