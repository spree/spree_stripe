module SpreeStripe
  class CreateTaxReversalJob < BaseJob
    def perform(refund_id)
      refund = Spree::Refund.find(refund_id)

      refund.with_lock { record_tax_reversal(refund) }
    end

    private

    # The reversal id is stored on the refund so a retry cannot record the same
    # refund twice - Stripe accepts repeated reversals of the same transaction and
    # would simply reverse the amount again.
    def record_tax_reversal(refund)
      return if refund.stripe_tax_reversal_id.present?

      payment = refund.payment
      tax_transaction_id = payment.stripe_tax_transaction_id
      return if tax_transaction_id.blank?

      gateway = payment.payment_method
      return unless gateway.is_a?(SpreeStripe::Gateway)

      amount_in_cents = refunded_amount_in_cents(refund, gateway)
      return unless amount_in_cents.positive?

      reversal = gateway.create_tax_reversal(
        tax_transaction_id,
        reference: "#{payment.response_code}-refund-#{refund.id}",
        flat_amount: -amount_in_cents,
        metadata: { refund: refund.id }
      )
      return if reversal.blank?

      refund.stripe_tax_reversal_id = reversal.id
      refund.update_column(:private_metadata, refund.private_metadata)
    end

    # The amount that actually left the account. Spree::Refund#amount can differ from
    # it, because #calculate_refund_amount is an extension point - spree_multi_vendor
    # adds tax on top of it - so the Stripe refund is the authority. Falls back to the
    # refund's own amount when it was never sent to Stripe.
    def refunded_amount_in_cents(refund, gateway)
      stripe_refund = retrieve_stripe_refund(refund, gateway)
      return stripe_refund.amount if stripe_refund.present?

      Spree::Money.new(refund.amount, currency: refund.currency).cents
    end

    def retrieve_stripe_refund(refund, gateway)
      return if refund.transaction_id.blank?

      gateway.retrieve_refund(refund.transaction_id)
    rescue Stripe::StripeError => e
      Rails.error.report(e, context: { refund_id: refund.id }, source: 'spree_stripe')
    end
  end
end
