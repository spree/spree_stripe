require 'spec_helper'

RSpec.describe SpreeStripe::CheckoutHelperDecorator, type: :helper do
  let(:payment_method) { create(:credit_card_payment_method, active: true) }
  let(:user) { create(:user) }
  let(:future_year) { Date.current.year + 2 }

  before do
    allow(helper).to receive(:try_spree_current_user).and_return(user)
  end

  describe '#checkout_payment_sources' do
    subject(:checkout_payment_sources) { helper.checkout_payment_sources(payment_method) }

    context 'when user has no payment sources' do
      it 'returns an empty array' do
        expect(checkout_payment_sources).to eq([])
      end
    end

    context 'when user has only non-wallet sources' do
      let!(:source1) do
        create(:credit_card,
          user: user,
          payment_method: payment_method,
          wallet: nil,
          gateway_customer_profile_id: 'profile_1',
          year: future_year,
          created_at: 2.days.ago
        )
      end

      let!(:source2) do
        create(:credit_card,
          user: user,
          payment_method: payment_method,
          wallet: {},
          gateway_customer_profile_id: 'profile_2',
          year: future_year,
          created_at: 1.day.ago
        )
      end

      it 'returns all non-wallet sources unchanged' do
        expect(checkout_payment_sources).to eq([source1, source2])
      end
    end

    context 'when user has only wallet sources' do
      let!(:wallet_source1) do
        create(:credit_card,
          user: user,
          payment_method: payment_method,
          wallet: { 'type' => 'apple_pay' },
          cc_type: 'visa',
          last_digits: '1234',
          month: 12,
          year: future_year,
          gateway_customer_profile_id: 'wallet_profile_1',
          created_at: 3.days.ago
        )
      end

      let!(:wallet_source2) do
        create(:credit_card,
          user: user,
          payment_method: payment_method,
          wallet: { 'type' => 'google_pay' },
          cc_type: 'mastercard',
          last_digits: '5678',
          month: 11,
          year: future_year,
          gateway_customer_profile_id: 'wallet_profile_2',
          created_at: 1.day.ago
        )
      end

      it 'returns all unique wallet sources ordered by created_at desc' do
        expect(checkout_payment_sources).to eq([wallet_source2, wallet_source1])
      end
    end

    context 'when user has duplicate wallet sources' do
      let!(:older_duplicate) do
        create(:credit_card,
          user: user,
          payment_method: payment_method,
          wallet: { 'type' => 'apple_pay' },
          cc_type: 'visa',
          last_digits: '1234',
          month: 12,
          year: future_year,
          gateway_customer_profile_id: 'wallet_profile_1',
          created_at: 3.days.ago
        )
      end

      let!(:newer_duplicate) do
        create(:credit_card,
          user: user,
          payment_method: payment_method,
          wallet: { 'type' => 'apple_pay' },
          cc_type: 'visa',
          last_digits: '1234',
          month: 12,
          year: future_year,
          gateway_customer_profile_id: 'wallet_profile_2',
          created_at: 1.day.ago
        )
      end

      let!(:different_wallet) do
        create(:credit_card,
          user: user,
          payment_method: payment_method,
          wallet: { 'type' => 'google_pay' },
          cc_type: 'visa',
          last_digits: '1234',
          month: 12,
          year: future_year,
          gateway_customer_profile_id: 'wallet_profile_3',
          created_at: 2.days.ago
        )
      end

      it 'returns only the newest duplicate wallet source' do
        expect(checkout_payment_sources).to eq([newer_duplicate, different_wallet])
        expect(checkout_payment_sources).not_to include(older_duplicate)
      end
    end

    context 'when user has both wallet and non-wallet sources' do
      let!(:non_wallet_source) do
        create(:credit_card,
          user: user,
          payment_method: payment_method,
          wallet: nil,
          gateway_customer_profile_id: 'profile_1',
          year: future_year,
          created_at: 4.days.ago
        )
      end

      let!(:wallet_source1) do
        create(:credit_card,
          user: user,
          payment_method: payment_method,
          wallet: { 'type' => 'apple_pay' },
          cc_type: 'visa',
          last_digits: '1234',
          month: 12,
          year: future_year,
          gateway_customer_profile_id: 'wallet_profile_2',
          created_at: 2.days.ago
        )
      end

      let!(:wallet_source2) do
        create(:credit_card,
          user: user,
          payment_method: payment_method,
          wallet: { 'type' => 'google_pay' },
          cc_type: 'mastercard',
          last_digits: '5678',
          month: 11,
          year: future_year,
          gateway_customer_profile_id: 'wallet_profile_3',
          created_at: 1.day.ago
        )
      end

      let!(:wallet_source3) do
        create(:credit_card,
          user: user,
          payment_method: payment_method,
          wallet: { 'type' => 'google_pay' },
          cc_type: 'mastercard',
          last_digits: '5678',
          month: 11,
          year: future_year,
          gateway_customer_profile_id: 'wallet_profile_4',
          created_at: 1.day.ago
        )
      end

      it 'returns non-wallet sources first, then unique wallet sources ordered by created_at desc' do
        expect(checkout_payment_sources).to eq([non_wallet_source, wallet_source3, wallet_source1])
      end
    end

    describe 'selecting only unique wallet sources' do
      let(:base_attributes) do
        {
          user: user,
          payment_method: payment_method,
          wallet: { 'type' => 'apple_pay' },
          cc_type: 'visa',
          last_digits: '1234',
          month: 12,
          year: future_year
        }
      end

      it 'includes both sources with different wallet_type' do
        source1 = create(:credit_card, **base_attributes, gateway_customer_profile_id: 'wallet_profile_1', created_at: 2.days.ago)
        source2 = create(:credit_card, **base_attributes.merge(wallet: { 'type' => 'google_pay' }, gateway_customer_profile_id: 'wallet_profile_2'), created_at: 1.day.ago)

        expect(checkout_payment_sources).to include(source1, source2)
      end

      it 'includes both sources with different cc_type' do
        source1 = create(:credit_card, **base_attributes, gateway_customer_profile_id: 'wallet_profile_1', created_at: 2.days.ago)
        source2 = create(:credit_card, **base_attributes.merge(cc_type: 'mastercard', gateway_customer_profile_id: 'wallet_profile_2'), created_at: 1.day.ago)

        expect(checkout_payment_sources).to include(source1, source2)
      end

      it 'includes both sources with different last_digits' do
        source1 = create(:credit_card, **base_attributes, gateway_customer_profile_id: 'wallet_profile_1', created_at: 2.days.ago)
        source2 = create(:credit_card, **base_attributes.merge(last_digits: '5678', gateway_customer_profile_id: 'wallet_profile_2'), created_at: 1.day.ago)

        expect(checkout_payment_sources).to include(source1, source2)
      end

      it 'includes both sources with different month' do
        source1 = create(:credit_card, **base_attributes, gateway_customer_profile_id: 'wallet_profile_1', created_at: 2.days.ago)
        source2 = create(:credit_card, **base_attributes.merge(month: 11, gateway_customer_profile_id: 'wallet_profile_2'), created_at: 1.day.ago)

        expect(checkout_payment_sources).to include(source1, source2)
      end

      it 'includes both sources with different year' do
        source1 = create(:credit_card, **base_attributes, gateway_customer_profile_id: 'wallet_profile_1', created_at: 2.days.ago)
        source2 = create(:credit_card, **base_attributes.merge(year: future_year + 1, gateway_customer_profile_id: 'wallet_profile_2'), created_at: 1.day.ago)

        expect(checkout_payment_sources).to include(source1, source2)
      end
    end
  end
end
