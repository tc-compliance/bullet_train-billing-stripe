class Billing::Price < ApplicationRecord
  self.table_name = "billing_prices"
  belongs_to :product, class_name: "Billing::Product"

  def trial_days
    self[:trial_days]
  end

  def allow_promotion_codes
    self[:allow_promotion_codes]
  end
end
