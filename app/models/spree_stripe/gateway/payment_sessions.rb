module SpreeStripe
  class Gateway < ::Spree::Gateway
    module PaymentSessions
      extend ActiveSupport::Concern

      def session_required?
        !SpreeStripe::Config[:use_legacy_payment_intents]
      end

      def payment_session_class
        Spree::PaymentSessions::Stripe
      end

      def create_payment_session(order:, amount: nil, external_data: {})
        total = amount.presence || order.total_minus_store_credits
        amount_in_cents = Spree::Money.new(total, currency: order.currency).cents

        return nil if amount_in_cents.zero?

        customer = fetch_or_create_customer(order: order)
        stripe_pm_id = external_data[:stripe_payment_method_id] || external_data['stripe_payment_method_id']

        response = create_payment_intent(
          amount_in_cents, order,
          payment_method_id: stripe_pm_id,
          customer_profile_id: customer&.profile_id
        )

        ephemeral_key_response = create_ephemeral_key(customer.profile_id) if customer.present?
        ephemeral_key_secret = ephemeral_key_response&.params['secret']

        payment_session_class.create!(
          order: order,
          payment_method: self,
          amount: total,
          currency: order.currency,
          status: 'pending',
          external_id: response.authorization,
          customer: order.user,
          customer_external_id: customer&.profile_id,
          external_data: {
            'client_secret' => response.params['client_secret'],
            'ephemeral_key_secret' => ephemeral_key_secret,
            'stripe_payment_method_id' => stripe_pm_id
          }.compact
        )
      end

      def update_payment_session(payment_session:, amount: nil, external_data: {})
        attrs = {}
        amount_in_cents = nil

        if amount.present?
          attrs[:amount] = amount
          amount_in_cents = Spree::Money.new(amount, currency: payment_session.currency).cents
        end

        stripe_pm_id = external_data[:stripe_payment_method_id] || external_data['stripe_payment_method_id']

        update_payment_intent(
          payment_session.external_id,
          amount_in_cents || payment_session.amount_in_cents,
          payment_session.order,
          stripe_pm_id
        )

        if external_data.present?
          attrs[:external_data] = (payment_session.external_data || {}).merge(external_data.stringify_keys)
        end

        payment_session.update!(attrs) if attrs.any?
      end

      def complete_payment_session(payment_session:, params: {})
        stripe_pi = retrieve_payment_intent(payment_session.external_id)

        if payment_intent_accepted?(stripe_pi)
          payment_session.process if payment_session.can_process?

          # PaymentSessions::Stripe duck-types as PaymentIntent
          SpreeStripe::CompleteOrder.new(payment_intent: payment_session).call

          payment_session.complete unless payment_session.completed?
        else
          payment_session.fail if payment_session.can_fail?
        end
      end
    end
  end
end
