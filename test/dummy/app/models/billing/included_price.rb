class Billing::IncludedPrice < ApplicationRecord
  self.table_name = "billing_included_prices"
  belongs_to :subscription, class_name: "Billing::Subscription"
  belongs_to :price, class_name: "Billing::Price"
end
