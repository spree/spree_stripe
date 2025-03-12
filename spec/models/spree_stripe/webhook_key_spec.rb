require 'spec_helper'

RSpec.describe SpreeStripe::WebhookKey do
  context 'validations' do
    context 'if webhook key already exists for specific payment method' do
      it 'raises validation error' do
        wk = create(:stripe_webhook_key)
        pm = wk.payment_methods.last

        expect { wk.payment_methods << pm }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'if webhook key does not exist for specific pm' do
      it 'does not raise a validation error' do
        wk = create(:stripe_webhook_key)
        pm = create(:stripe_gateway)

        expect { wk.payment_methods << pm }.not_to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
