module Spree
  class PaymentSessions::Stripe < PaymentSession
    delegate :api_options, to: :payment_method

    # Duck-type interface matching SpreeStripe::PaymentIntent
    # This allows reuse of CompleteOrder and CreatePayment services
    def stripe_id
      external_id
    end

    def client_secret
      external_data&.dig('client_secret')
    end

    def ephemeral_key_secret
      external_data&.dig('ephemeral_key_secret')
    end

    def stripe_payment_intent
      @stripe_payment_intent ||= payment_method.retrieve_payment_intent(external_id)
    end

    def stripe_charge
      @stripe_charge ||= begin
        latest_charge = stripe_payment_intent.latest_charge
        latest_charge.present? ? payment_method.retrieve_charge(latest_charge) : nil
      end
    end

    def accepted?
      payment_method.payment_intent_accepted?(stripe_payment_intent)
    end

    def successful?
      stripe_payment_intent.status == 'succeeded'
    end

    def charge_not_required?
      payment_method.payment_intent_charge_not_required?(stripe_payment_intent)
    end

    def find_or_create_payment!
      return unless persisted?
      return payment if payment.present?

      SpreeStripe::CreatePayment.new(
        order: order,
        payment_intent: self,
        gateway: payment_method,
        amount: amount
      ).call
    end
  end
end
