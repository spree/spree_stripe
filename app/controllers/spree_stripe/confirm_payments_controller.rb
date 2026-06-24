# Stripe redirects here after payment confirmation. Mirrors the Next.js storefront's server-side
# completion: finalizes the payment session + order via existing services, then
# redirects to the confirmation page. Completion is idempotent — an already-completed
# order (e.g. the webhook won the race) is treated as success.
module SpreeStripe
  class ConfirmPaymentsController < (defined?(Spree::StoreController) ? Spree::StoreController : Spree::BaseController)
    include Spree::CheckoutAnalyticsHelper if defined?(Spree::CheckoutAnalyticsHelper)

    # GET /stripe/confirm_payment/:id?session=ps_...&redirect_status=...
    def show
      @order = current_store.orders.find_by_prefix_id!(params[:id])

      return redirect_to_cart_canceled if @order.canceled?
      return redirect_to_complete if @order.completed?

      payment_session = @order.payment_sessions.find_by_prefix_id!(params[:session])
      payment_session.payment_method.complete_payment_session(
        payment_session: payment_session,
        params: { session_result: params[:redirect_status] }
      )

      return handle_failure(payment_session.errors.full_messages.to_sentence) unless payment_session.completed?

      Spree::Dependencies.carts_complete_service.constantize.call(cart: @order) unless @order.completed?

      if @order.reload.completed?
        track_checkout_completed if respond_to?(:track_checkout_completed)
        redirect_to_complete
      else
        handle_failure
      end
    rescue Spree::Core::GatewayError => e
      handle_failure(e.message)
    end

    private

    def redirect_to_complete
      redirect_to spree.checkout_complete_path(@order.token), status: :see_other
    end

    def redirect_to_cart_canceled
      flash[:error] = Spree.t(:order_canceled)
      redirect_to spree.cart_path, status: :see_other
    end

    def handle_failure(message = nil)
      flash[:error] = message.presence || Spree.t('stripe.payment_could_not_be_processed')
      redirect_to spree.checkout_state_path(@order.token, 'payment'), status: :see_other
    end
  end
end
