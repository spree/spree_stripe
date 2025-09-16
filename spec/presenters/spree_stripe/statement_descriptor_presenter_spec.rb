require 'spec_helper'

RSpec.describe SpreeStripe::StatementDescriptorPresenter do
  subject(:presenter) { described_class.new(order_number: order_number, store_billing_name: store_billing_name).call }

  let(:order_number) { 'R123456789' }
  let(:store_billing_name) { 'Test Store' }

  context 'when the descriptor is within the max length' do
    it 'returns the order number and store billing name' do
      expect(subject).to eq("#{order_number} #{store_billing_name}")
    end
  end

  context 'when the descriptor exceeds the max length' do
    let(:store_billing_name) { 'A' * 30 }

    it 'truncates the descriptor to 22 characters' do
      expect(subject.length).to eq(22)
    end
  end

  context 'when the store billing name contains not allowed characters' do
    let(:store_billing_name) { "Store <Name> 'Test' *" }

    it 'replaces not allowed characters with dashes' do
      expect(subject).to include('-')
      expect(subject).not_to include('<')
      expect(subject).not_to include('>')
      expect(subject).not_to include("'")
      expect(subject).not_to include('*')
      expect(subject).not_to include('"')
      expect(subject).not_to include("\\")
    end
  end

  context 'when the store billing name contains unicode characters' do
    let(:store_billing_name) { 'Tëst Štørę' }

    it 'transliterates unicode characters' do
      expect(subject).to eq("#{order_number} Test Store")
    end
  end

  context 'when the store billing name has leading and trailing spaces' do
    let(:store_billing_name) { '  My Store  ' }

    it 'strips the spaces before building the descriptor' do
      expect(subject).to eq("#{order_number} My Store")
    end
  end
end
