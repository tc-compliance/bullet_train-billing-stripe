class Account::Billing::Stripe::SubscriptionsController < Account::ApplicationController
  account_load_and_authorize_resource :subscription, through: :team, through_association: :billing_stripe_subscriptions, member_actions: [:checkout, :refresh, :portal]

  # GET/POST /account/billing/stripe/subscriptions/:id/checkout
  # GET/POST /account/billing/stripe/subscriptions/:id/checkout.json
  def checkout
    trial_days = @subscription.generic_subscription.included_prices.map { |ip| ip.price.trial_days }.compact.max
    allow_promotion_codes = @subscription.generic_subscription.included_prices.map { |ip| ip.price.allow_promotion_codes }.compact.any?
    customer_auto_update_attributes =
      if @team.stripe_customer_id
        {customer_update: {name: "auto", address: "auto"}}
      else
        {}
      end

    session_attributes = {
      payment_method_types: ["card"],
      subscription_data: {
        items: @subscription.stripe_items,
        trial_settings: {end_behavior: {missing_payment_method: "cancel"}}
      }.merge(trial_days ? {trial_period_days: trial_days} : {}),
      customer: @team.stripe_customer_id,
      client_reference_id: @subscription.id,
      success_url: CGI.unescape(url_for([:refresh, :account, @subscription, session_id: "{CHECKOUT_SESSION_ID}"])),
      cancel_url: url_for([:account, @subscription.generic_subscription]),
      allow_promotion_codes: allow_promotion_codes,
      payment_method_collection: "if_required",
      tax_id_collection: {enabled: true},
      **customer_auto_update_attributes
    }

    unless @team.stripe_customer_id
      session_attributes[:customer_email] = current_membership.email
    end

    idempotency_key = self.class.build_checkout_idempotency_key(
      app_name: t("application.name"),
      subscription_id: @subscription.id,
      session_attributes: session_attributes
    )

    session = Stripe::Checkout::Session.create(session_attributes, idempotency_key: idempotency_key)

    redirect_to session.url, allow_other_host: true
  end

  # POST /account/billing/stripe/subscriptions/:id/portal
  # POST /account/billing/stripe/subscriptions/:id/portal.json
  def portal
    session = Stripe::BillingPortal::Session.create({
      customer: @team.stripe_customer_id,
      return_url: url_for([:account, @subscription.generic_subscription])
    })

    redirect_to session.url, allow_other_host: true
  end

  # GET /account/billing/stripe/subscriptions/:id/refresh
  # GET /account/billing/stripe/subscriptions/:id/refresh.json
  def refresh
    # If the checkout session is paid already, we want to do a couple things quickly without waiting for a webhook.
    checkout_session = Stripe::Checkout::Session.retrieve(params[:session_id])
    @subscription.refresh_from_checkout_session(checkout_session)

    redirect_to [:account, @subscription.generic_subscription.team], notice: t("billing/stripe/subscriptions.notifications.refreshed")
  end

  # Generates a deterministic idempotency key from the actual Stripe Checkout
  # Session attributes. This ensures the key changes whenever any parameter
  # changes (e.g. team gains a stripe_customer_id between attempts) and stays
  # stable for truly identical requests.
  #
  # Extracted as a class method so it can be unit-tested without a full
  # controller stack.
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
