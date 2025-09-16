require 'spec_helper'

RSpec.describe SpreeStripe::StatementDescriptorPresenter do
  subject(:presenter) { described_class.new(order_number: order_number, store_billing_name: store_billing_name).call }

  let(:order_number) { 'R123456789' }
  let(:store_billing_name) { 'Test Store' }

  context 'when the descriptor is within the max length' do
    it 'returns the order number and store billing name' do
      expect(subject).to eq("R123456789 TEST STORE")
    end
  end

  context 'when the descriptor exceeds the max length' do
    let(:store_billing_name) { 'A' * 30 }

    it 'truncates the descriptor to 22 characters' do
      expect(subject.length).to eq(22)
    end
  end

  context 'with leading and trailing spaces after parsing' do
    let(:store_billing_name) { 'AAAAA                B' }

    it 'strips the spaces' do
      expect(subject).to eq("R123456789 AAAAA")
    end
  end

  context 'when the store billing name contains not allowed characters' do
    let(:store_billing_name) { "store <x> 'T' *" }

    it 'removes not allowed characters' do
      expect(subject).to eq("R123456789 STORE X T")
    end
  end

  context 'when the store billing name contains unicode characters' do
    let(:store_billing_name) { 'Tëst Štørę' }

    it 'transliterates unicode characters' do
      expect(subject).to eq("R123456789 TEST STORE")
    end
  end

  context 'when the store billing name has leading and trailing spaces' do
    let(:store_billing_name) { '  My Store  ' }

    it 'strips the spaces before building the descriptor' do
      expect(subject).to eq("R123456789 MY STORE")
    end
  end
end
