require "test_helper"

class CheckoutIdempotencyKeyTest < ActiveSupport::TestCase
  test "identical attributes produce the same key" do
    attrs = {customer: "cus_123", payment_method_types: ["card"], subscription_data: {items: [{price: "price_1"}]}}

    key1 = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 60, session_attributes: attrs)
    key2 = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 60, session_attributes: attrs)

    assert_equal key1, key2
  end

  test "different attributes produce different keys" do
    base = {customer: nil, customer_email: "user@example.com", payment_method_types: ["card"]}
    changed = {customer: "cus_123", customer_update: {name: "auto"}, payment_method_types: ["card"]}

    key1 = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 60, session_attributes: base)
    key2 = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 60, session_attributes: changed)

    refute_equal key1, key2
  end

  test "hash key insertion order does not affect the key" do
    attrs_a = {zebra: 1, alpha: 2, middle: 3}
    attrs_b = {alpha: 2, middle: 3, zebra: 1}

    key_a = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_a)
    key_b = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_b)

    assert_equal key_a, key_b
  end

  test "nested hash key order does not affect the key" do
    attrs_a = {outer: {zebra: 1, alpha: {deep: true, shallow: false}}}
    attrs_b = {outer: {alpha: {shallow: false, deep: true}, zebra: 1}}

    key_a = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_a)
    key_b = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_b)

    assert_equal key_a, key_b
  end

  test "different subscription IDs produce different keys" do
    attrs = {customer: "cus_123"}

    key1 = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs)
    key2 = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 2, session_attributes: attrs)

    refute_equal key1, key2
  end

  test "key format is app_name:subscription:id:32-char-hex" do
    attrs = {customer: "cus_123"}

    key = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "MyApp", subscription_id: 42, session_attributes: attrs)

    assert_match(/\AMyApp:subscription:42:[0-9a-f]{32}\z/, key)
  end

  test "array order is preserved (items order matters to Stripe)" do
    attrs_a = {items: [{price: "price_1"}, {price: "price_2"}]}
    attrs_b = {items: [{price: "price_2"}, {price: "price_1"}]}

    key_a = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_a)
    key_b = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_b)

    refute_equal key_a, key_b
  end

  test "array of hashes with different inner insertion order produces the same key" do
    attrs_a = {items: [{b: 2, a: 1}]}
    attrs_b = {items: [{a: 1, b: 2}]}

    key_a = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_a)
    key_b = Account::Billing::Stripe::SubscriptionsController.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_b)

    assert_equal key_a, key_b
  end
end
