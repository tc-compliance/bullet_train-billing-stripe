require "test_helper"
require "digest"
require "json"

class CheckoutIdempotencyKeyTest < ActiveSupport::TestCase
  # Minimal stub so we can call the class method without loading the full
  # controller hierarchy.
  class KeyBuilder
    def self.build_checkout_idempotency_key(app_name:, subscription_id:, session_attributes:)
      canonical = deep_sort_keys(session_attributes.as_json)
      fingerprint = Digest::SHA256.hexdigest(JSON.generate(canonical))[0, 32]
      "#{app_name}:subscription:#{subscription_id}:#{fingerprint}"
    end

    def self.deep_sort_keys(obj)
      case obj
      when Hash
        obj.sort_by { |k, _| k.to_s }.map { |k, v| [k, deep_sort_keys(v)] }.to_h
      when Array
        obj.map { |v| deep_sort_keys(v) }
      else
        obj
      end
    end
  end

  test "identical attributes produce the same key" do
    attrs = { customer: "cus_123", payment_method_types: ["card"], subscription_data: { items: [{ price: "price_1" }] } }

    key1 = KeyBuilder.build_checkout_idempotency_key(app_name: "CC", subscription_id: 60, session_attributes: attrs)
    key2 = KeyBuilder.build_checkout_idempotency_key(app_name: "CC", subscription_id: 60, session_attributes: attrs)

    assert_equal key1, key2
  end

  test "different attributes produce different keys" do
    base = { customer: nil, customer_email: "user@example.com", payment_method_types: ["card"] }
    changed = { customer: "cus_123", customer_update: { name: "auto" }, payment_method_types: ["card"] }

    key1 = KeyBuilder.build_checkout_idempotency_key(app_name: "CC", subscription_id: 60, session_attributes: base)
    key2 = KeyBuilder.build_checkout_idempotency_key(app_name: "CC", subscription_id: 60, session_attributes: changed)

    refute_equal key1, key2
  end

  test "hash key insertion order does not affect the key" do
    attrs_a = { zebra: 1, alpha: 2, middle: 3 }
    attrs_b = { alpha: 2, middle: 3, zebra: 1 }

    key_a = KeyBuilder.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_a)
    key_b = KeyBuilder.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_b)

    assert_equal key_a, key_b
  end

  test "nested hash key order does not affect the key" do
    attrs_a = { outer: { zebra: 1, alpha: { deep: true, shallow: false } } }
    attrs_b = { outer: { alpha: { shallow: false, deep: true }, zebra: 1 } }

    key_a = KeyBuilder.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_a)
    key_b = KeyBuilder.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_b)

    assert_equal key_a, key_b
  end

  test "different subscription IDs produce different keys" do
    attrs = { customer: "cus_123" }

    key1 = KeyBuilder.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs)
    key2 = KeyBuilder.build_checkout_idempotency_key(app_name: "CC", subscription_id: 2, session_attributes: attrs)

    refute_equal key1, key2
  end

  test "key format is app_name:subscription:id:32-char-hex" do
    attrs = { customer: "cus_123" }

    key = KeyBuilder.build_checkout_idempotency_key(app_name: "MyApp", subscription_id: 42, session_attributes: attrs)

    assert_match(/\AMyApp:subscription:42:[0-9a-f]{32}\z/, key)
  end

  test "array order is preserved (items order matters to Stripe)" do
    attrs_a = { items: [{ price: "price_1" }, { price: "price_2" }] }
    attrs_b = { items: [{ price: "price_2" }, { price: "price_1" }] }

    key_a = KeyBuilder.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_a)
    key_b = KeyBuilder.build_checkout_idempotency_key(app_name: "CC", subscription_id: 1, session_attributes: attrs_b)

    refute_equal key_a, key_b
  end
end
