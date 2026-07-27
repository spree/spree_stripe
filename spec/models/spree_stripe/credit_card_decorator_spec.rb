require 'spec_helper'

RSpec.describe SpreeStripe::CreditCardDecorator, type: :model do
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

  describe 'fingerprint uniqueness' do
    let(:user) { create(:user) }
    let(:payment_method) { create(:stripe_gateway) }
    let!(:existing) do
      create(:credit_card, user: user, payment_method: payment_method,
                           fingerprint: 'FZqjhq46SWprIY8i', month: 2, year: 2030)
    end

    it 'rejects a second card with the same fingerprint and expiry for the user and payment method' do
      duplicate = build(:credit_card, user: user, payment_method: payment_method,
                                      fingerprint: 'FZqjhq46SWprIY8i', month: 2, year: 2030)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:fingerprint]).to be_present
    end

    it 'allows the same fingerprint with a different expiry' do
      other = build(:credit_card, user: user, payment_method: payment_method,
                                  fingerprint: 'FZqjhq46SWprIY8i', month: 12, year: 2031)

      expect(other).to be_valid
    end
  end
end
