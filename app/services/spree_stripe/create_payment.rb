module SpreeStripe
  class CreatePayment
    def initialize(order:, payment_intent:, gateway: nil, tax_transaction: nil, amount: nil)
      @order = order
      @gateway = gateway || order.store.stripe_gateway
      @payment_intent = payment_intent
      @tax_transaction = tax_transaction
      @amount = amount || order.total_minus_store_credits
    end

    def call
      stripe_charge = payment_intent.stripe_charge

      if stripe_charge.present?
        source = SpreeStripe::CreateSource.new(
          order: order,
          stripe_payment_method_details: stripe_charge.payment_method_details,
          stripe_payment_method_id: stripe_charge.payment_method,
          stripe_billing_details: stripe_charge.billing_details,
          gateway: gateway
        ).call
      elsif payment_intent.charge_not_required?
        stripe_payment_intent = payment_intent.stripe_payment_intent
        source = SpreeStripe::CreateSource.new(
          order: order,
          stripe_payment_method_details: stripe_payment_intent.payment_method,
          stripe_payment_method_id: stripe_payment_intent.payment_method.id,
          stripe_billing_details: nil,
          gateway: gateway
        ).call
      end

      # sometimes a job is re-tried and creates a double payment record so we need to avoid it!
      payment = order.payments.find_or_initialize_by(
        payment_method_id: gateway.id,
        response_code: payment_intent.stripe_id,
        amount: amount
      )

      payment.source = source if source.present?
      payment.stripe_tax_transaction_id = tax_transaction
      payment.stripe_charge_id = stripe_charge&.id

      payment.save!
      payment
    end

    private

    attr_reader :order, :gateway, :payment_intent, :tax_transaction, :source, :amount
  end
end
