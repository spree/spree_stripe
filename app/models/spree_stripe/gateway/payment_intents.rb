module SpreeStripe
  class Gateway < ::Spree::Gateway
    module PaymentIntents
      extend ActiveSupport::Concern

      DELAYED_NOTIFICATION_PAYMENT_METHOD_TYPES = %w[sepa_debit us_bank_account].freeze
      BANK_PAYMENT_METHOD_TYPES = %w[customer_balance us_bank_account].freeze

      included do
        has_many :payment_intents, class_name: 'SpreeStripe::PaymentIntent', foreign_key: 'payment_method_id', dependent: :delete_all
      end

      def payment_intent_accepted?(payment_intent)
        payment_intent.status.in?(payment_intent_accepted_statuses(payment_intent))
      end

      def payment_intent_delayed_notification?(payment_intent)
        payment_method = payment_intent.payment_method
        return false unless payment_method.respond_to?(:type)

        payment_intent.payment_method.type.in?(DELAYED_NOTIFICATION_PAYMENT_METHOD_TYPES)
      end

      def payment_intent_charge_not_required?(payment_intent)
        payment_intent_bank_payment_method?(payment_intent)
      end

      def payment_intent_bank_payment_method?(payment_intent)
        payment_method = payment_intent.payment_method
        return false unless payment_method.respond_to?(:type)

        payment_intent.payment_method.type.in?(BANK_PAYMENT_METHOD_TYPES)
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
          response = send_request { |opts| Stripe::PaymentIntent.create(payload, opts) }

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

          response = send_request { |opts| Stripe::PaymentIntent.update(payment_intent_id, payload, opts) }

          success(response.id, response)
        end
      end

      def retrieve_payment_intent(payment_intent_id)
        send_request { |opts| Stripe::PaymentIntent.retrieve({ id: payment_intent_id, expand: ['payment_method'] }, opts) }
      end

      def confirm_payment_intent(payment_intent_id)
        send_request { |opts| Stripe::PaymentIntent.confirm(payment_intent_id, {}, opts) }
      end

      def capture_payment_intent(payment_intent_id, amount_in_cents)
        send_request { |opts| Stripe::PaymentIntent.capture(payment_intent_id, { amount_to_capture: amount_in_cents }, opts) }
      end

      # Cancels a Stripe payment intent
      #
      # @param payment_intent_id [String] Stripe payment intent ID, eg. pi_123
      def cancel_payment_intent(payment_intent_id)
        send_request { |opts| Stripe::PaymentIntent.cancel(payment_intent_id, {}, opts) }
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

      private

      def payment_intent_accepted_statuses(payment_intent)
        statuses = %w[succeeded]
        statuses << 'processing' if payment_intent_delayed_notification?(payment_intent)
        statuses << 'requires_action' if payment_intent_charge_not_required?(payment_intent)
        statuses
      end
    end
  end
end
