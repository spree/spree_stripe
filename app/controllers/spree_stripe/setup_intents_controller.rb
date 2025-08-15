module SpreeStripe
  class SetupIntentsController < Spree::StoreController
    # GET /stripe/setup_intents/callback
    def callback
      setup_intent_id = params[:setup_intent]

      if setup_intent_id.blank?
        set_error_flash_message
        return redirect_to spree.account_credit_cards_path
      end

      setup_intent = current_store.stripe_gateway.retrieve_setup_intent(setup_intent_id)
      setup_intent.status == 'succeeded' ? set_success_flash_message : set_error_flash_message

      redirect_to spree.account_credit_cards_path
    rescue Spree::Core::GatewayError => e
      set_error_flash_message
      redirect_to spree.account_credit_cards_path
    end

    private

    def set_error_flash_message
      flash[:error] = Spree.t('storefront.credit_cards.create_error')
    end

    def set_success_flash_message
      flash[:notice] = Spree.t('storefront.credit_cards.create_success')
    end
  end
end
