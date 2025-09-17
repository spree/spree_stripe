require 'spec_helper'

RSpec.describe SpreeStripe::StatementDescriptorSuffixPresenter do
  subject(:presenter) { described_class.new(order_description: order_description) }

  describe '#call' do
    context 'when order_description contains allowed characters' do
      let(:order_description) { 'Order123' }

      it 'returns the upcased order description' do
        expect(presenter.call).to eq('ORDER123')
      end
    end

    context 'when order_description contains not allowed characters' do
      let(:order_description) { "Order<1>'*2\\" }

      it 'removes not allowed characters' do
        expect(presenter.call).to eq('ORDER12')
      end
    end

    context 'when order_description contains lowercase and spaces' do
      let(:order_description) { 'order 123' }

      it 'upcases and trims spaces' do
        expect(presenter.call).to eq('ORDER 123')
      end
    end

    context 'when order_description is longer than max chars' do
      let(:order_description) { 'ABCDEFGHIJKL' }

      it 'truncates to max chars' do
        expect(presenter.call.length).to eq(described_class::STATEMENT_DESCRIPTOR_MAX_CHARS)
        expect(presenter.call).to eq('ABCDEFGHIJ')
      end
    end

    context 'when order_description contains unicode characters' do
      let(:order_description) { 'Café Über' }

      it 'transliterates unicode to ascii' do
        expect(presenter.call).to eq('CAFE UBER')
      end
    end

    context 'when order_description is blank' do
      let(:order_description) { '' }

      it 'returns an empty string' do
        expect(presenter.call).to eq('')
      end
    end

    context 'when order_description has leading and trailing spaces' do
      let(:order_description) { '  order 123  ' }

      it 'strips spaces' do
        expect(presenter.call).to eq('ORDER 123')
      end
    end
  end
end
