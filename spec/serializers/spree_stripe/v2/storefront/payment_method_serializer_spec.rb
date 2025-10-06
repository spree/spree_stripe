require 'spec_helper'

describe Spree::V2::Storefront::PaymentMethodSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params) }

  let!(:store) { Spree::Store.default }
  let(:resource) { create(:stripe_gateway) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: resource.id.to_s,
          type: :payment_method,
          attributes: {
            name: resource.name,
            description: resource.description,
            type: resource.type,
            publishable_key: resource.preferred_publishable_key,
            preferences: {},
            public_metadata: {},
          },
          relationships: {
            metafields: {
              data: []
            },
          }
        }
      }
    )
  end
end
