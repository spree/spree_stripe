require 'spec_helper'

RSpec.describe SpreeStripe::PaymentDecorator do
  let(:store) { Spree::Store.default }
  let(:user) { create(:user) }
  let(:order) { create(:order_with_line_items, store: store, user: user) }
  let(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }

  let!(:stripe_customer) { create(:gateway_customer, user: user, payment_method: stripe_gateway, profile_id: 'cus_123') }
  let(:source) do
    create(:credit_card,
      user: user,
      payment_method: stripe_gateway,
      gateway_customer_profile_id: stripe_customer.profile_id,
      private_metadata: {
        checks: {
          address_line1_check: 'pass',
          address_postal_code_check: 'pass',
          cvc_check: 'pass'
        }
      }
    )
  end

  let(:payment) { create(:payment, order: order, payment_method: stripe_gateway, amount: order.total_minus_store_credits, source: source) }

  describe '#set_cvv_and_avs_response_from_metadata' do
    context 'with credit card source' do
      it 'sets the avs_response and cvv_response_code' do
        expect(payment.avs_response).to eq('Y')
        expect(payment.cvv_response_code).to eq('M')
      end

      context 'AVS checks' do
        shared_examples_for 'storing the AVS code' do |street_check, postal_code_check, code|
          context "when street check: #{street_check}, postal code check: #{postal_code_check}" do
            let(:source) do
              create(:credit_card,
                user: user,
                payment_method: stripe_gateway,
                gateway_customer_profile_id: stripe_customer.profile_id,
                private_metadata: {
                  checks: {
                    address_line1_check: street_check,
                    address_postal_code_check: postal_code_check,
                    cvc_check: 'pass'
                  }
                }
              )
            end

            it "stores the AVS code: #{code}" do
              expect(payment.avs_response).to eq(code)
            end
          end
        end

        it_behaves_like 'storing the AVS code', 'pass', 'pass', 'Y'
        it_behaves_like 'storing the AVS code', 'pass', 'fail', 'A'
        it_behaves_like 'storing the AVS code', 'pass', 'unchecked', 'B'
        it_behaves_like 'storing the AVS code', 'fail', 'pass', 'Z'
        it_behaves_like 'storing the AVS code', 'fail', 'fail', 'N'
        it_behaves_like 'storing the AVS code', 'unchecked', 'pass', 'P'
        it_behaves_like 'storing the AVS code', 'unchecked', 'unchecked', 'I'
      end

      context 'CVV checks' do
        shared_examples_for 'storing the CVV code' do |cvc_check, code|
          context "when CVC check: #{cvc_check}" do
            let(:source) do
              create(:credit_card,
                user: user,
                payment_method: stripe_gateway,
                gateway_customer_profile_id: stripe_customer.profile_id,
                private_metadata: {
                  checks: {
                    address_line1_check: 'pass',
                    address_postal_code_check: 'pass',
                    cvc_check: cvc_check
                  }
                }
              )
            end

            it "stores the CVV code: #{code}" do
              expect(payment.cvv_response_code).to eq(code)
            end
          end
        end

        it_behaves_like 'storing the CVV code', 'pass', 'M'
        it_behaves_like 'storing the CVV code', 'fail', 'N'
        it_behaves_like 'storing the CVV code', 'unchecked', 'P'
      end
    end

    context 'with non-credit card source' do
      let(:source) { create(:klarna_payment_source) }
      let(:payment) { create(:payment, order: order, payment_method: stripe_gateway, amount: order.total_minus_store_credits, source: source) }

      it 'does not set the avs_response and cvv_response_code' do
        expect(payment.avs_response).to be_nil
        expect(payment.cvv_response_code).to be_nil
      end
    end
  end

  describe 'after_transition to :completed' do
    subject { payment.complete! }

    let(:payment) do
      create(:payment, order: order, payment_method: stripe_gateway, response_code: 'pi_1234567890', amount: order.total)
    end

    before { order.update(stripe_tax_calculation_id: 'taxcalc_1234567890') }

    it 'records the tax transaction' do
      expect { subject }.to have_enqueued_job(SpreeStripe::CreateTaxTransactionJob).with(payment.id)
    end

    context 'when the order has no tax calculation' do
      before { order.update(stripe_tax_calculation_id: nil) }

      it 'does not record a tax transaction' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::CreateTaxTransactionJob)
      end
    end

    context 'when the tax transaction has already been recorded' do
      before { payment.update(stripe_tax_transaction_id: 'tax_1234567890') }

      it 'does not record it again' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::CreateTaxTransactionJob)
      end
    end

    context 'when the payment has no payment intent' do
      before { payment.update_column(:response_code, nil) }

      it 'does not record a tax transaction' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::CreateTaxTransactionJob)
      end
    end

    context 'when the payment is not a Stripe one' do
      let(:payment) { create(:payment, order: order, response_code: 'pi_1234567890', amount: order.total) }

      it 'does not record a tax transaction' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::CreateTaxTransactionJob)
      end
    end
  end
end
