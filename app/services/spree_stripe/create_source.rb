module SpreeStripe
  class CreateSource
    def initialize(payment_method_details:, payment_method_id:, gateway:, billing_details:, order: nil, user: nil)
      @payment_method_details = payment_method_details
      @payment_method_id = payment_method_id
      @gateway = gateway
      @user = user || order&.user
      @billing_details = billing_details
      @order = order
    end

    def call
      case payment_method_details.type
      when 'card'
        find_or_create_credit_card
      when 'klarna'
        SpreeStripe::PaymentSources::Klarna.create!(source_params)
      when 'afterpay_clearpay'
        SpreeStripe::PaymentSources::AfterPay.create!(source_params)
      when 'sepa_debit'
        SpreeStripe::PaymentSources::SepaDebit.create!(source_params)
      when 'p24'
        SpreeStripe::PaymentSources::Przelewy24.create!(source_params.merge(bank: payment_method_details.p24.bank))
      when 'ideal'
        SpreeStripe::PaymentSources::Ideal.create!(
          source_params.merge(
            bank: payment_method_details.ideal.bank,
            last4: payment_method_details.ideal.iban_last4
          )
        )
      when 'alipay'
        SpreeStripe::PaymentSources::Alipay.create!(source_params)
      when 'link'
        SpreeStripe::PaymentSources::Link.create!(source_params)
      when 'affirm'
        SpreeStripe::PaymentSources::Affirm.create!(source_params)
      else
        raise "[STRIPE] Unknown payment method #{payment_method_details.type}"
      end
    end

    private

    attr_reader :gateway, :user, :payment_method_details, :payment_method_id, :billing_details, :order

    def find_or_create_credit_card
      if user
        source = user.credit_cards.find_by(gateway_payment_profile_id: payment_method_id)

        return source if source
      end

      Spree::CreditCard.create!(credit_card_params)
    end

    def credit_card_params
      card_details = payment_method_details.card
      customer = gateway.fetch_or_create_customer(user: user, order: order)

      {
        user: user,
        gateway_customer: customer,
        payment_method: gateway,
        gateway_customer_profile_id: customer&.profile_id,
        gateway_payment_profile_id: payment_method_id,
        name: billing_details.name,
        month: card_details.exp_month,
        year: card_details.exp_year,
        last_digits: card_details.last4,
        brand: card_details.brand,
        private_metadata: payment_method_details.card
      }
    end

    def source_params
      {
        gateway_payment_profile_id: payment_method_id,
        payment_method: gateway
      }
    end
  end
end
