module SpreeStripe
  class CreateSource
    def initialize(stripe_charge:, order:, gateway:)
      @order = order
      @stripe_charge = stripe_charge
      @gateway = gateway
    end

    def call
      payment_method_details = stripe_charge.payment_method_details

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
        raise "[STRIPE] ORDER #{order.number} Unknown payment method #{payment_method_details.type}"
      end
    end

    private

    attr_reader :order, :stripe_charge, :gateway

    delegate :user, to: :order

    def find_or_create_credit_card
      if user
        source = user.credit_cards.find_by(gateway_payment_profile_id: stripe_charge.payment_method)

        return source if source
      end

      Spree::CreditCard.create!(credit_card_params)
    end

    def credit_card_params
      card_details = stripe_charge.payment_method_details.card
      customer = gateway.fetch_or_create_customer(order: order, user: user)

      {
        user: user,
        customer: customer,
        payment_method: gateway,
        gateway_customer_profile_id: customer&.profile_id,
        gateway_payment_profile_id: stripe_charge.payment_method,
        name: stripe_charge.billing_details.name,
        month: card_details.exp_month,
        year: card_details.exp_year,
        last_digits: card_details.last4,
        brand: card_details.brand,
        private_metadata: stripe_charge.payment_method_details.card
      }
    end

    def source_params
      {
        gateway_payment_profile_id: stripe_charge.payment_method,
        payment_method: gateway
      }
    end
  end
end
