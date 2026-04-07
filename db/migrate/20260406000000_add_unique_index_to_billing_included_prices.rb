class AddUniqueIndexToBillingIncludedPrices < ActiveRecord::Migration[6.1]
  def change
    add_index :billing_included_prices, [:subscription_id, :price_id], unique: true, name: "idx_included_prices_on_subscription_and_price"
  end
end
