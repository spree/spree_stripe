require 'spec_helper'

RSpec.describe SpreeStripe::ConfirmPaymentsController, type: :controller do
  let(:store) { Spree::Store.default }
  let(:gateway) { create(:stripe_gateway, stores: [store]) }
  let(:order) { create(:order_with_line_items, store: store, state: 'payment') }
  let(:payment_session) { create(:stripe_payment_session, order: order, payment_method: gateway, status: 'pending') }

  let(:params) { { id: order.prefixed_id, session: payment_session.prefixed_id, redirect_status: 'succeeded' } }

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(controller).to receive(:track_checkout_completed)
  end

  describe 'GET #show' do
    context 'when the session and order complete' do
      # complete_payment_session is exercised against Stripe in complete_order_spec + the
      # gateway spec; here we stub only that gateway call and let the real Spree::Carts::Complete
      # finish a paid order.
      let!(:payment) { create(:payment, order: order, amount: order.total, state: 'completed') }

      before do
        allow_any_instance_of(SpreeStripe::Gateway).to receive(:complete_payment_session) do |_gateway, **kwargs|
          kwargs[:payment_session].update_column(:status, 'completed')
        end
      end

      it 'completes the order and redirects to the confirmation page' do
        get :show, params: params
        expect(order.reload).to be_completed
        expect(response).to redirect_to(spree.checkout_complete_path(order.token))
      end
    end

    context 'when the order is already completed' do
      before { order.update_columns(state: 'complete', completed_at: Time.current) }

      it 'redirects straight to the confirmation page' do
        get :show, params: params
        expect(response).to redirect_to(spree.checkout_complete_path(order.token))
      end
    end

    context 'when the order is canceled' do
      before { order.update_columns(state: 'canceled', canceled_at: Time.current) }

      it 'redirects to the cart with an error' do
        get :show, params: params
        expect(response).to redirect_to(spree.cart_path)
        expect(flash[:error]).to be_present
      end
    end

    context 'when the payment session does not complete' do
      before do
        allow_any_instance_of(SpreeStripe::Gateway).to receive(:complete_payment_session) do |_gateway, **kwargs|
          kwargs[:payment_session].update_column(:status, 'failed')
        end
      end

      it 'redirects back to the payment step with an error' do
        get :show, params: params
        expect(response).to redirect_to(spree.checkout_state_path(order.token, 'payment'))
        expect(flash[:error]).to be_present
      end
    end

    context 'when the session id is unknown' do
      it 'raises RecordNotFound (404)' do
        expect { get :show, params: params.merge(session: 'ps_unknown') }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
