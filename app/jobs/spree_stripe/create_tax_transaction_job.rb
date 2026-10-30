module SpreeStripe
  class CreateTaxTransactionJob < BaseJob
    def perform(payment_id)
      payment = Spree::Payment.find(payment_id)

      payment.with_lock { record_tax_transaction(payment) }
    end

    private

    # Re-checked under the lock: a payment can reach :completed more than once - for
    # instance when an order is completed from the checkout and from the
    # payment_intent.succeeded webhook - and a calculation may only be recorded once.
    def record_tax_transaction(payment)
      return if payment.stripe_tax_transaction_id.present?

      tax_calculation_id = payment.order.stripe_tax_calculation_id
      return if tax_calculation_id.blank?

      gateway = payment.payment_method
      return unless gateway.is_a?(SpreeStripe::Gateway)

      transaction = gateway.create_tax_transaction(payment.response_code, tax_calculation_id)
      return if transaction.blank?

      payment.stripe_tax_transaction_id = transaction.id
      payment.update_column(:private_metadata, payment.private_metadata)
    end
  end
end
