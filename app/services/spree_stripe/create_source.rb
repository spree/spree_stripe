module SpreeStripe
  class CreateSource
    def initialize(stripe_payment_method_details:, stripe_payment_method_id:, gateway:, stripe_billing_details:, order: nil, user: nil)
      @stripe_payment_method_details = stripe_payment_method_details
      @stripe_payment_method_id = stripe_payment_method_id
      @gateway = gateway
      @user = user || order&.user
      @stripe_billing_details = stripe_billing_details
      @order = order
    end

    def call
      case stripe_payment_method_details.type
      when 'card'
        find_or_create_credit_card
      when 'klarna'
        SpreeStripe::PaymentSources::Klarna.create!(source_params)
      when 'afterpay_clearpay'
        SpreeStripe::PaymentSources::AfterPay.create!(source_params)
      when 'sepa_debit'
        SpreeStripe::PaymentSources::SepaDebit.create!(source_params)
      when 'p24'
        SpreeStripe::PaymentSources::Przelewy24.create!(source_params.merge(bank: stripe_payment_method_details.p24.bank))
      when 'ideal'
        SpreeStripe::PaymentSources::Ideal.create!(
          source_params.merge(
            bank: stripe_payment_method_details.ideal.bank,
            last4: stripe_payment_method_details.ideal.iban_last4
          )
        )
      when 'alipay'
        SpreeStripe::PaymentSources::Alipay.create!(source_params)
      when 'link'
        SpreeStripe::PaymentSources::Link.create!(source_params)
      when 'affirm'
        SpreeStripe::PaymentSources::Affirm.create!(source_params)
      when 'customer_balance', 'us_bank_account'
        SpreeStripe::PaymentSources::BankTransfer.create!(source_params)
      else
        raise "[STRIPE] Unknown payment method #{stripe_payment_method_details.type}"
      end
    end

    private

    attr_reader :gateway, :user, :stripe_payment_method_details, :stripe_payment_method_id, :stripe_billing_details, :order

    def find_or_create_credit_card
      if user
        source = user.credit_cards.find_by(gateway_payment_profile_id: stripe_payment_method_id)

        return source if source
      end

      Spree::CreditCard.create!(credit_card_params)
    end

    def credit_card_params
      card_details = stripe_payment_method_details.card
      customer = gateway.fetch_or_create_customer(user: user, order: order)

      {
        user: user,
        gateway_customer: customer,
        payment_method: gateway,
        gateway_customer_profile_id: customer&.profile_id,
        gateway_payment_profile_id: stripe_payment_method_id,
        name: stripe_billing_details.name,
        month: card_details.exp_month,
        year: card_details.exp_year,
        last_digits: card_details.last4,
        brand: card_details.brand,
        private_metadata: {
          checks: stripe_payment_method_details.card&.checks,
          wallet: {
            type: stripe_payment_method_details.card&.wallet&.type
          }
        }
      }
    end

    def source_params
      {
        gateway_payment_profile_id: stripe_payment_method_id,
        payment_method: gateway
      }
    end
  end
end
