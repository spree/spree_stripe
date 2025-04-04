module Spree
  module Api
    module V2
      module Storefront
        module Stripe
          class PaymentIntentsController < BaseController
            include Spree::Api::V2::Storefront::OrderConcern
            before_action :ensure_order, except: [:confirm]

            # POST /api/v2/storefront/stripe/payment_intents
            def create
              spree_authorize! :update, spree_current_order, order_token

              stripe_payment_method_id = permitted_attributes[:stripe_payment_method_id].presence
              stripe_payment_method_id ||= spree_current_order.valid_credit_cards.where(payment_method: stripe_gateway).first&.gateway_payment_profile_id

              @payment_intent = SpreeStripe::CreatePaymentIntent.new.call(
                spree_current_order,
                stripe_gateway,
                stripe_payment_method_id: stripe_payment_method_id,
                off_session: permitted_attributes[:off_session].to_b || false
              )

              render_serialized_payload { serialize_resource(@payment_intent) }
            end

            # GET /api/v2/storefront/stripe/payment_intents
            def show
              spree_authorize! :show, spree_current_order, order_token

              @payment_intent = spree_current_order.payment_intents.find(params[:id])

              render_serialized_payload { serialize_resource(@payment_intent) }
            end

            # PATCH /api/v2/storefront/stripe/payment_intents/:id
            def update
              spree_authorize! :update, spree_current_order, order_token

              @payment_intent = spree_current_order.payment_intents.find(params[:id])
              @payment_intent.attributes = permitted_attributes.except(:off_session)
              @payment_intent.save!

              render_serialized_payload { serialize_resource(@payment_intent) }
            end

            def confirm
              @payment_intent = SpreeStripe::PaymentIntent.find(params[:id])

              stripe_payment_intent = @payment_intent.stripe_payment_intent
              order = @payment_intent.order

              if order.canceled?
                render_error_payload(Spree.t('order_canceled'))
              elsif order.completed?
                render_error_payload(Spree.t('order_already_completed'))
              elsif order != spree_current_order
                raise ActiveRecord::RecordNotFound
              elsif stripe_payment_intent.status == 'succeeded'
                spree_authorize! :update, spree_current_order, order_token

                SpreeStripe::CompleteOrder.new(payment_intent: @payment_intent).call

                render_serialized_payload { serialize_resource(@payment_intent) }
              else
                render_error_payload(Spree.t("stripe.payment_intent_errors.#{stripe_payment_intent.status}"))
              end
            rescue Spree::Core::GatewayError => e
              render_error_payload(e.message)
            end

            private

            def permitted_attributes
              params.require(:payment_intent).permit(:amount, :stripe_payment_method_id, :off_session)
            end

            def resource_serializer
              Spree::V2::Storefront::PaymentIntentSerializer
            end
          end
        end
      end
    end
  end
end
