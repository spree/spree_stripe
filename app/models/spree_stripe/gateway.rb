module SpreeStripe
  class Gateway < ::Spree::Gateway
    include SpreeStripe::Gateway::Tax if defined?(SpreeStripe::Gateway::Tax)

    preference :publishable_key, :password
    preference :secret_key, :password

    has_one_attached :apple_developer_merchantid_domain_association, service: Spree.private_storage_service_name

    validates :preferred_secret_key, :preferred_publishable_key, presence: true
    validate :validate_secret_key, unless: -> { Rails.env.test? }, if: -> { preferred_secret_key.present? }

    after_commit :create_webhook_endpoint_async, on: %i[create update]
    after_commit :register_domain, on: :create

    has_many :payment_intents, class_name: 'SpreeStripe::PaymentIntent', foreign_key: 'payment_method_id', dependent: :delete_all

    def webhook_url
      StripeEvent::Engine.routes.url_helpers.root_url(host: 'https://shop.mbvendo.ngrok.app', protocol: 'https')
    end

    def provider_class
      self.class
    end

    # @param amount_in_cents [Integer] the amount in cents to capture
    # @param payment_source [Spree::CreditCard | Spree::PaymentSource]
    # @param gateway_options [Hash] this is an instance of Spree::Payment::GatewayOptions.to_hash
    def authorize(amount_in_cents, payment_source, gateway_options = {})
      handle_authorize_or_purchase(amount_in_cents, payment_source, gateway_options)
    end

    # @param amount_in_cents [Integer] the amount in cents to capture
    # @param payment_source [Spree::CreditCard | Spree::PaymentSource]
    # @param gateway_options [Hash] this is an instance of Spree::Payment::GatewayOptions.to_hash
    def purchase(amount_in_cents, payment_source, gateway_options = {})
      handle_authorize_or_purchase(amount_in_cents, payment_source, gateway_options)
    end

    # the behavior for authorize and purchase is the same, so we can use the same method to handle both
    def handle_authorize_or_purchase(amount_in_cents, payment_source, gateway_options)
      order_number, payment_number = gateway_options[:order_id].split('-')

      return failure('Order number is invalid') if order_number.blank?
      return failure('Payment number is invalid') if payment_number.blank?

      order = Spree::Order.where(store_id: stores.ids).find_by(number: order_number)
      payment = order.payments.find_by(number: payment_number)

      protect_from_error do
        # eg. payment created via admin
        payment = ensure_payment_intent_exists_for_payment(payment, amount_in_cents, payment_source)
        stripe_payment_intent = retrieve_payment_intent(payment.response_code)

        response = if stripe_payment_intent.status == 'succeeded'
                     # payment intent is already confirmed via Stripe JS SDK
                     stripe_payment_intent
                   else
                     confirm_payment_intent(stripe_payment_intent.id)
                   end

        success(response.id, response)
      end
    end

    def credit(amount_in_cents, _source, payment_intent_id, _gateway_options = {})
      protect_from_error do
        payload = {
          amount: amount_in_cents,
          payment_intent: payment_intent_id
        }

        response = send_request { Stripe::Refund.create(payload) }

        success(response.id, response)
      end
    end

    def capture(amount_in_cents, payment_intent_id, _gateway_options = {})
      protect_from_error do
        stripe_payment_intent = retrieve_payment_intent(payment_intent_id)

        response = if stripe_payment_intent.status == 'requires_capture'
                     capture_payment_intent(payment_intent_id, amount_in_cents)
                   elsif stripe_payment_intent.status == 'succeeded'
                     stripe_payment_intent
                   else
                     raise Spree::Core::GatewayError, "Payment intent status is #{stripe_payment_intent.status}"
                   end

        success(response.id, response)
      end
    end

    def void(response_code, source, gateway_options)
      raise NotImplementedError
    end

    def cancel(payment_intent_id, payment = nil)
      protect_from_error do
        if payment&.completed?
          amount = payment.credit_allowed
          return success(payment_intent_id, {}) if amount.zero?
          # Don't create a refund if the payment is for a shipment, we will create a refund for the whole shipping cost instead
          return success(payment_intent_id, {}) if payment.respond_to?(:for_shipment?) && payment.for_shipment?

          refund = payment.refunds.create!(
            amount: amount,
            reason: Spree::RefundReason.order_canceled_reason,
            refunder_id: payment.order.canceler_id
          )

          # Spree::Refund#response has the response from the `credit` action
          # For the authorization ID we need to use the payment.response_code (the payment intent ID)
          # Otherwise we'll overwrite the payment authorization with the refund ID
          success(payment.response_code, refund.response.params)
        else
          response = cancel_payment_intent(payment_intent_id)
          success(response.id, response)
        end
      end
    end

    def fetch_or_create_customer(order: nil, user: nil)
      user ||= order&.user
      return nil unless user

      gateway_customers.find_by(user: user) || create_customer(order: order, user: user)
    end

    # Creates a Stripe customer based on the order or user
    #
    # @param order [Spree::Order] the order to use for creating the Stripe customer
    # @param user [Spree::User] the user to use for creating the Stripe customer
    # @return [Stripe::Customer] the created Stripe customer
    def create_customer(order: nil, user: nil)
      payload = build_customer_payload(order: order, user: user)
      response = send_request { Stripe::Customer.create(payload) }

      customer = gateway_customers.build(user: user, profile_id: response.id)
      customer.save! if user.present?
      customer
    end

    # Updates a Stripe customer based on the order or user
    #
    # @param order [Spree::Order] the order to use for updating the Stripe customer
    # @param user [Spree::User] the user to use for updating the Stripe customer
    # @return [Stripe::Customer] the updated Stripe customer
    def update_customer(order: nil, user: nil)
      user ||= order&.user
      return if user.blank?

      customer = gateway_customers.find_by(user: user)
      return if customer.blank?

      payload = build_customer_payload(order: order, user: user)
      send_request { Stripe::Customer.update(customer.profile_id, payload) }
    end

    # Creates a Stripe payment intent for the order
    #
    # @param amount_in_cents [Integer] the amount in cents
    # @param order [Spree::Order] the order to create a payment intent for
    # @param payment_method_id [String] Stripe payment method id to use, eg. a card token
    # @param off_session [Boolean] whether the payment intent is off session
    # @param customer_profile_id [String] Stripe customer profile id to use, eg.  cus_123
    # @return [ActiveMerchant::Billing::Response] the response from the payment intent creation
    def create_payment_intent(amount_in_cents, order, payment_method_id: nil, off_session: false, customer_profile_id: nil)
      payload = SpreeStripe::PaymentIntentPresenter.new(
        amount: amount_in_cents,
        order: order,
        customer: customer_profile_id || fetch_or_create_customer(order: order)&.profile_id,
        payment_method_id: payment_method_id,
        off_session: off_session
      ).call

      protect_from_error do
        response = send_request { Stripe::PaymentIntent.create(payload) }

        success(response.id, response)
      end
    end

    # Updates a Stripe payment intent for the order
    #
    # @param payment_intent_id [String] Stripe payment intent id
    # @param amount_in_cents [Integer] the amount in cents
    # @param order [Spree::Order] the order to update the payment intent for
    # @param payment_method_id [String] Stripe payment method id to use, eg. a card token
    # @return [ActiveMerchant::Billing::Response] the response from the payment intent update
    def update_payment_intent(payment_intent_id, amount_in_cents, order, payment_method_id = nil)
      protect_from_error do
        payload = SpreeStripe::PaymentIntentPresenter.new(
          amount: amount_in_cents,
          order: order,
          customer: fetch_or_create_customer(order: order)&.profile_id,
          payment_method_id: payment_method_id
        ).call.slice(:amount, :currency, :payment_method, :shipping, :customer)

        response = send_request { Stripe::PaymentIntent.update(payment_intent_id, payload) }

        success(response.id, response)
      end
    end

    def retrieve_payment_intent(payment_intent_id)
      send_request { Stripe::PaymentIntent.retrieve(payment_intent_id) }
    end

    def confirm_payment_intent(payment_intent_id)
      send_request { Stripe::PaymentIntent.confirm(payment_intent_id) }
    end

    def capture_payment_intent(payment_intent_id, amount_in_cents)
      send_request { Stripe::PaymentIntent.capture(payment_intent_id, { amount_to_capture: amount_in_cents }) }
    end

    # Cancels a Stripe payment intent
    #
    # @param payment_intent_id [String] Stripe payment intent ID, eg. pi_123
    def cancel_payment_intent(payment_intent_id)
      send_request { Stripe::PaymentIntent.cancel(payment_intent_id) }
    end

    # Ensures a Stripe payment intent exists for Spree payment
    #
    # @param payment [Spree::Payment] the payment to ensure a payment intent exists for
    # @param amount_in_cents [Integer] the amount in cents
    # @param payment_source [Spree::CreditCard | Spree::PaymentSource] the payment source to use
    # @return [Spree::Payment] the payment with the payment intent
    def ensure_payment_intent_exists_for_payment(payment, amount_in_cents = nil, payment_source = nil)
      return payment if payment.response_code.present?

      amount_in_cents ||= payment.display_amount.cents
      payment_source ||= payment.source

      response = create_payment_intent(
        amount_in_cents,
        payment.order,
        payment_method_id: payment_source.gateway_payment_profile_id,
        off_session: true,
        customer_profile_id: payment_source.gateway_customer_profile_id
      )

      payment.update_columns(
        response_code: response.authorization,
        updated_at: Time.current
      )

      payment
    end

    def retrieve_charge(charge_id)
      send_request { Stripe::Charge.retrieve(charge_id) }
    end

    def create_ephemeral_key(customer_id)
      protect_from_error do
        response = send_request { Stripe::EphemeralKey.create({ customer: customer_id }, { stripe_version: Stripe.api_version }) }

        success(response.secret, response)
      end
    end

    def create_setup_intent(customer_id, payment_methods = [])
      options = if payment_methods.empty?
                  { automatic_payment_methods: { enabled: true } }
                else
                  { payment_method_types: payment_methods }
                end

      protect_from_error do
        response = send_request { Stripe::SetupIntent.create(customer: customer_id, **options) }

        success(response.client_secret, response)
      end
    end

    def retrieve_setup_intent(setup_intent_id)
      protect_from_error do
        send_request { Stripe::SetupIntent.retrieve(setup_intent_id) }
      end
    end

    def apple_domain_association_file_content
      @apple_domain_association_file_content ||= apple_developer_merchantid_domain_association&.download
    end

    def payment_profiles_supported?
      true
    end

    def default_name
      'Stripe'
    end

    def method_type
      'spree_stripe'
    end

    def payment_icon_name
      'stripe'
    end

    def description_partial_name
      'spree_stripe'
    end

    def custom_form_fields_partial_name
      'spree_stripe'
    end

    def configuration_guide_partial_name
      'spree_stripe'
    end

    def gateway_dashboard_payment_url(payment)
      return if payment.transaction_id.blank?

      "https://dashboard.stripe.com/payments/#{payment.transaction_id}"
    end

    def create_webhook_endpoint
      SpreeStripe::CreateGatewayWebhooks.new.call(payment_method: self)
    end

    def create_profile(payment)
      customer = fetch_or_create_customer(order: payment.order)

      payment.source.update(gateway_customer_profile_id: customer.profile_id) if payment.source.present? && customer.present?
    end

    def api_options
      { api_key: preferred_secret_key, api_version: Stripe.api_version }
    end

    def send_request(&block)
      result, _response = client.request(&block)
      result
    end

    def client
      @client ||= Stripe::StripeClient.new(api_options)
    end

    private

    def validate_secret_key
      Stripe::Refund.list({ limit: 0 }, api_options)
    rescue Stripe::AuthenticationError
      errors.add(:base, 'Secret key is invalid')
    rescue Stripe::PermissionError => e
      errors.add(:base, 'You have provided your publishable key instead of your secret key') if e.error&.code == 'secret_key_required'
    rescue Stripe::StripeError
      errors.add(:base, 'Something went wrong with Stripe. Try again later.')
    end

    def success(authorization, full_response)
      ActiveMerchant::Billing::Response.new(true, nil, full_response.as_json, authorization: authorization)
    end

    def failure(error = nil)
      ActiveMerchant::Billing::Response.new(false, error)
    end

    def protect_from_error
      yield
    rescue Stripe::StripeError => e
      raise Spree::Core::GatewayError, e.message
    end

    def create_webhook_endpoint_async
      return if webhook_keys.any?

      SpreeStripe::CreateWebhookEndpointJob.perform_later(id)
    end

    def register_domain
      stores.each do |store|
        RegisterDomainJob.perform_later(store.id, 'store')

        store.custom_domains.each do |custom_domain|
          RegisterDomainJob.perform_later(custom_domain.id, 'custom_domain')
        end
      end
    end

    def build_customer_payload(order: nil, user: nil)
      user ||= order&.user
      address = order&.bill_address || user&.bill_address
      name = order&.name || user&.name
      email = order&.email || user&.email

      SpreeStripe::CustomerPresenter.new(name: name, email: email, address: address).call
    end
  end
end
