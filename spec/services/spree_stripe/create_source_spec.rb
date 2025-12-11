require 'spec_helper'

RSpec.describe SpreeStripe::CreateSource do
  subject do
    described_class.new(
      user: user,
      stripe_payment_method_id: source_id,
      stripe_payment_method_details: payment_method_details,
      gateway: gateway,
      stripe_billing_details: billing_details
    ).call
  end

  let(:order) { create(:order) }
  let(:user) { create(:user) }
  let!(:gateway) { create(:stripe_gateway, stores: [order.store]) }
  let(:source_id) { 'source_id' }

  let(:stripe_charge) do
    Stripe::StripeObject.construct_from(
      id: 'stripe_charge_id',
      payment_method_details: payment_method_details,
      payment_method: source_id,
      customer: 'cus_123'
    )
  end

  let(:billing_details) do
    Stripe::StripeObject.construct_from(
      name: 'John Snow'
    )
  end

  let(:payment_method_details) do
    Stripe::StripeObject.construct_from(
      card: Stripe::StripeObject.construct_from(
        brand: 'mastercard',
        checks: Stripe::StripeObject.construct_from(
          address_line1_check: 'unchecked',
          address_postal_code_check: 'unchecked',
          cvc_check: nil
        ),
        country: 'PL',
        exp_month: 11,
        exp_year: 2025,
        fingerprint: 'FZqjhq46SWprIY8i',
        funding: 'debit',
        installments: nil,
        last4: '3522',
        mandate: nil,
        network: 'mastercard',
        three_d_secure: nil,
        wallet: Stripe::StripeObject.construct_from(
          apple_pay: nil,
          dynamic_last4: '3139',
          type: 'apple_pay'
        )
      ),
      type: 'card'
    )
  end

  describe '#call' do
    context 'user is nil' do
      let(:user) { nil }

      it 'creates a source not assigned to the user' do
        expect { subject }.to change { Spree::CreditCard.count }.by 1
        expect(subject.user).to eq nil
      end
    end

    context 'if the order belongs to the user' do
      let(:order) { create(:order, user: user) }

      context 'if the user already has CC with the same profile_id' do
        let!(:credit_card) { create(:credit_card, user: user, gateway_payment_profile_id: source_id) }

        it 'returns already created CC' do
          expect(subject).to eq(credit_card)
        end
      end

      context 'if the user does not have a CC' do
        let!(:customer) { create(:gateway_customer, user: order.user, payment_method: gateway) }

        it 'creates a new source' do
          expect { subject }.to change { user.credit_cards.count }.by 1

          expect(subject.month).to eq 11
          expect(subject.year).to eq 2025
          expect(subject.last_digits).to eq '3522'
          expect(subject.gateway_payment_profile_id).to eq source_id
          expect(subject.user).to eq user
          expect(subject.brand).to eq 'master'
          expect(subject.payment_method).to eq gateway
          expect(subject.private_metadata).to eq(
            'wallet' => { 'type' => 'apple_pay' },
            'checks' => { 'address_line1_check' => 'unchecked',
                          'address_postal_code_check' => 'unchecked', 'cvc_check' => nil }
          )
        end
      end
    end

    context 'if source is klarna' do
      let(:payment_method_details) do
        Stripe::StripeObject.construct_from(
          klarna: Stripe::StripeObject.construct_from(
            payment_method_category: 'pay_in_installments',
            preferred_locale: 'en-US'
          ),
          type: 'klarna'
        )
      end

      it 'create a Klarna source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::Klarna)
      end
    end

    context 'if source is clearpay_afterpay' do
      let(:payment_method_details) { Stripe::StripeObject.construct_from(type: 'afterpay_clearpay') }

      it 'create a AfterPay source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::AfterPay)
      end
    end

    context 'if source is sepa_debit' do
      let(:payment_method_details) { Stripe::StripeObject.construct_from(type: 'sepa_debit') }

      it 'create a SepaDebit source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::SepaDebit)
      end
    end

    context 'when source is customer_balance' do
      let(:payment_method_details) { Stripe::StripeObject.construct_from(type: 'customer_balance') }

      it 'create a BankTransfer source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::BankTransfer)
      end
    end

    context 'when source is us_bank_account' do
      let(:payment_method_details) { Stripe::StripeObject.construct_from(type: 'us_bank_account') }

      it 'create a BankTransfer source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::BankTransfer)
      end
    end

    context 'if source is p24' do
      let(:payment_method_details) do
        Stripe::StripeObject.construct_from(
          p24: Stripe::StripeObject.construct_from(
            bank: 'ing',
            reference: 'P24-N01-101-101 R751406491',
            verified_name: 'Jenny Rosen'
          ),
          type: 'p24'
        )
      end

      it 'create a Przelewy24 source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::Przelewy24)
        expect(subject.bank).to eq 'ing'
      end
    end

    context 'if source is alipay' do
      let(:payment_method_details) do
        Stripe::StripeObject.construct_from(
          alipay: Stripe::StripeObject.construct_from(
            fingerprint: nil,
            transaction_id: nil
          ),
          type: 'alipay'
        )
      end

      it 'create a Alipay source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::Alipay)
      end
    end

    context 'if source is affirm' do
      let(:payment_method_details) { Stripe::StripeObject.construct_from(type: 'affirm') }

      it 'create a Affirm source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::Affirm)
      end
    end

    context 'if source is ideal' do
      let(:payment_method_details) do
        Stripe::StripeObject.construct_from(
          ideal: Stripe::StripeObject.construct_from(
            bank: 'rabobank',
            bic: 'RABONL2U',
            generated_sepa_debit: nil,
            generated_sepa_debit_mandate: nil,
            iban_last4: '5264',
            verified_name: 'Jenny Rosen'
          ),
          type: 'ideal'
        )
      end

      it 'create a Ideal source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::Ideal)
        expect(subject.bank).to eq 'rabobank'
        expect(subject.last4).to eq '5264'
      end
    end

    context 'if source is link' do
      let(:payment_method_details) do
        Stripe::StripeObject.construct_from(
          link: Stripe::StripeObject.new,
          type: 'link'
        )
      end

      it 'create a Link source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::Link)
      end
    end
  end
end
