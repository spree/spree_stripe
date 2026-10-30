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

      reversal = create_reversal(gateway, refund, payment, tax_transaction_id)
      return if reversal.blank?

      refund.stripe_tax_reversal_id = reversal.id
      refund.update_column(:private_metadata, refund.private_metadata)
    end

    def create_reversal(gateway, refund, payment, tax_transaction_id)
      if fully_refunded?(refund, payment)
        gateway.create_tax_reversal(
          tax_transaction_id,
          mode: 'full',
          reference: reversal_reference(refund, payment),
          metadata: { refund: refund.id }
        )
      else
        amount_in_cents = refunded_amount_in_cents(refund, gateway)
        return unless amount_in_cents.positive?

        gateway.create_tax_reversal(
          tax_transaction_id,
          mode: 'partial',
          reference: reversal_reference(refund, payment),
          flat_amount: -amount_in_cents,
          metadata: { refund: refund.id }
        )
      end
    end

    # A full reversal mirrors the original line items with opposite signs, which keeps
    # each line's taxability reason intact.
    def fully_refunded?(refund, payment)
      return false if reversed_before?(refund, payment)

      # The void and failed payment states are excluded because Spree::Order#order_refunded?
      # treats them as fully refunded whether or not the refunds add up.
      order = payment.order.reload
      return false if order.payment_state.in?(%w[void failed])

      order.order_refunded?
    end

    # A full reversal does not account for earlier partial ones, so it would reverse their amounts a second time.
    def reversed_before?(refund, payment)
      payment.refunds.where.not(id: refund.id).any? { |other| other.stripe_tax_reversal_id.present? }
    end

    def reversal_reference(refund, payment)
      "#{payment.response_code}-refund-#{refund.id}"
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
