module SpreeStripe
  module RefundReasonDecorator
    def self.prepended(base)
      base.const_set(:ORDER_CANCELED_REASON, 'Order Canceled')

      def base.order_canceled_reason
        find_or_create_by(name: Spree::RefundReason::ORDER_CANCELED_REASON, mutable: false)
      end
    end
  end
end

Spree::RefundReason.prepend(SpreeStripe::RefundReasonDecorator)
