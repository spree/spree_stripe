require 'spec_helper'

RSpec.describe SpreeStripe::CreditCardDecorator, type: :model do
  describe '#wallet_type' do
    context 'without wallet' do
      let(:credit_card) { create(:credit_card) }

      it { expect(credit_card.wallet_type).to be_nil }
    end

    context 'with wallet' do
      let(:credit_card) { create(:credit_card, private_metadata: stripe_hash) }
      let(:stripe_hash) do
        {
          "brand": "mastercard",
          "checks": {
            "address_line1_check": "unchecked",
            "address_postal_code_check": "unchecked",
            "cvc_check": nil
          },
          "country": "PL",
          "exp_month": 11,
          "exp_year": 2025,
          "fingerprint": "FZqjhq46SWprIY8i",
          "funding": "debit",
          "installments": nil,
          "last4": "3522",
          "mandate": nil,
          "network": "mastercard",
          "three_d_secure": nil,
          "wallet": {
            "apple_pay": {
            },
            "dynamic_last4": "3139",
            "type": "apple_pay"
          }
        }
      end

      it { expect(credit_card.wallet_type).to eq('apple_pay') }
    end
  end

  describe '.by_fingerprint' do
    let!(:match) { create(:credit_card, fingerprint: 'FZqjhq46SWprIY8i', month: 2, year: 2030) }
    let!(:other_fingerprint) { create(:credit_card, fingerprint: 'differentFingerprint', month: 2, year: 2030) }
    let!(:other_expiry) { create(:credit_card, fingerprint: 'FZqjhq46SWprIY8i', month: 12, year: 2031) }

    it 'returns cards matching the fingerprint and expiry' do
      expect(Spree::CreditCard.by_fingerprint('FZqjhq46SWprIY8i', 2, 2030)).to contain_exactly(match)
    end

    it 'matches when month and year are passed as strings' do
      expect(Spree::CreditCard.by_fingerprint('FZqjhq46SWprIY8i', '2', '2030')).to contain_exactly(match)
    end

    it 'returns nothing when the expiry differs' do
      expect(Spree::CreditCard.by_fingerprint('FZqjhq46SWprIY8i', 1, 2030)).to be_empty
    end
  end
end
