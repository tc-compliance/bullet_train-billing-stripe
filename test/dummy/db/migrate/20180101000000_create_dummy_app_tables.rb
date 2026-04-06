class CreateDummyAppTables < ActiveRecord::Migration[6.1]
  def change
    create_table :teams do |t|
      t.string :name
      t.timestamps
    end

    create_table :billing_subscriptions do |t|
      t.string :provider_subscription_type
      t.integer :provider_subscription_id
      t.references :team, foreign_key: true
      t.integer :status, default: 0
      t.datetime :cycle_ends_at
      t.timestamps
    end

    create_table :billing_included_prices do |t|
      t.references :subscription, foreign_key: {to_table: :billing_subscriptions}
      t.references :price, foreign_key: {to_table: :billing_prices}
      t.integer :quantity, default: 1
      t.timestamps
    end

    create_table :billing_products do |t|
      t.string :name
      t.timestamps
    end

    create_table :billing_prices do |t|
      t.references :product, foreign_key: {to_table: :billing_products}
      t.string :stripe_price_id
      t.integer :trial_days
      t.boolean :allow_promotion_codes, default: false
      t.timestamps
    end
  end
end
