# this is the endpoint that Stripe JS SDK will redirect customer to after payment
# it will handle the payment intent status and process the payment
module SpreeStripe
  class PaymentIntentsController < Spree::BaseController
    include Spree::CheckoutAnalyticsHelper if defined?(Spree::CheckoutAnalyticsHelper)

    # GET /spree/payment_intents/:id
    def show
      # fetch the payment intent active record
      @payment_intent_record = SpreeStripe::PaymentIntent.find(params[:id])

      # fetch the stripe payment intent
      @stripe_payment_intent = @payment_intent_record.stripe_payment_intent

      @order = @payment_intent_record.order

      # if somehow order was canceled, we need to redirect the customer to the cart
      # this is a rare case, but we need to handle it
      if @order.canceled?
        flash[:error] = Spree.t(:order_canceled)
        redirect_to spree.cart_path, status: :see_other
      # if the order is already completed (race condition)
      # we need to redirect the customer to the complete checkout page
      # but we need to make sure not to set the session flag to indicate that the order was placed now
      # because we don't know if the order was actually placed or not
      elsif @order.completed?
        redirect_to spree.checkout_complete_path(@order.token), status: :see_other
      # if the payment intent is successful, we need to process the payment and complete the order
      elsif @payment_intent_record.accepted?
        @order = SpreeStripe::CompleteOrder.new(payment_intent: @payment_intent_record).call

        # set the session flag to indicate that the order was placed now
        track_checkout_completed if @order.completed?

        # redirect the customer to the complete checkout page
        redirect_to spree.checkout_complete_path(@order.token), status: :see_other
      else
        handle_failure(Spree.t("stripe.payment_intent_errors.#{@stripe_payment_intent.status}"))
      end
    rescue Spree::Core::GatewayError => e
      handle_failure(e.message)
    end

    private

    def handle_failure(error_message)
      flash[:error] = error_message

      Rails.logger.error("Payment failed for order #{@order.id}: #{@stripe_payment_intent.status}")

      # remove the payment intent record, so after returning to the checkout page, the customer can try again with a new payment intent
      @payment_intent_record.destroy!

      # this should be a rare race condition, but we need to handle it
      payment = @order.payments.valid.find_by(response_code: @stripe_payment_intent.id)
      payment.void! if payment.present?

      redirect_to spree.checkout_path(@order.token), status: :see_other
    end
  end
end
