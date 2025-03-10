require 'spec_helper'

RSpec.describe SpreeStripe::WebhookHandlers::PaymentIntentSucceeded do
  describe '#call' do
    subject { described_class.new.call(event) }

    let(:store) { Spree::Store.default }
    let(:order) { create(:order_with_line_items, store: store) }
    let(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }
    let!(:payment_intent) { create(:payment_intent, order: order, payment_method: stripe_gateway, stripe_id: payment_intent_id) }
    let(:payment_intent_id) { 'pi_3Kf5vdDFyWwdfZQ10kAY6fo0' }

    let(:event) do
      Stripe::Event.construct_from(
        {
          id: 'evt_2Zj5zzFU3a9abcZ1aYYYaaZ1',
          object: 'event',
          api_version: '2020-08-27',
          created: 1_633_887_337,
          data: {
            object: {
              id: payment_intent_id,
              object: 'payment_intent',
              amount: 3149,
              amount_capturable: 0,
              amount_received: 3149,
              application: 'ca_KgrEhoa8d1lwpnOtleu5SixG6TSBujzF',
              application_fee_amount: nil,
              automatic_payment_methods: {
                enabled: true
              },
              canceled_at: nil,
              cancellation_reason: nil,
              capture_method: 'automatic',
              charges: {
                object: 'list',
                data: [
                  {
                    id: 'ch_3Kf5vdDFyWwdfZQ10hH9aseO',
                    object: 'charge',
                    amount: 3149,
                    amount_captured: 3149,
                    amount_refunded: 0,
                    application: 'ca_KgrEhoa8d1lwpnOtleu5SixG6TSBujzF',
                    application_fee: nil,
                    application_fee_amount: nil,
                    balance_transaction: 'txn_3Kf5vdDFyWwdfZQ10ugSK6a4',
                    billing_details: {
                      address: {
                        city: nil,
                        country: 'PL',
                        line1: nil,
                        line2: nil,
                        postal_code: nil,
                        state: nil
                      },
                      email: nil,
                      name: nil,
                      phone: nil
                    },
                    calculated_statement_descriptor_suffix: 'R290961888',
                    captured: true,
                    created: 1_647_710_374,
                    currency: 'usd',
                    customer: nil,
                    description: nil,
                    destination: nil,
                    dispute: nil,
                    disputed: false,
                    failure_code: nil,
                    failure_message: nil,
                    fraud_details: {
                    },
                    invoice: nil,
                    livemode: false,
                    metadata: {
                      spree_order_id: '189c52c8-3573-455f-b44f-afeb8518d5e0'
                    },
                    on_behalf_of: nil,
                    order: nil,
                    outcome: {
                      network_status: 'approved_by_network',
                      reason: nil,
                      risk_level: 'normal',
                      risk_score: 4,
                      seller_message: 'Payment complete.',
                      type: 'authorized'
                    },
                    paid: true,
                    payment_intent: 'pi_3Kf5vdDFyWwdfZQ10kAY6fo0',
                    payment_method: 'pm_1Kf5w9DFyWwdfZQ1ofFYsuxi',
                    payment_method_details: {
                      card: {
                        brand: 'visa',
                        checks: {
                          address_line1_check: nil,
                          address_postal_code_check: nil,
                          cvc_check: 'pass'
                        },
                        country: 'US',
                        exp_month: 11,
                        exp_year: 2023,
                        fingerprint: 'gZngKRQNYlpck69a',
                        funding: 'credit',
                        installments: nil,
                        last4: '4242',
                        mandate: nil,
                        network: 'visa',
                        three_d_secure: nil,
                        wallet: nil
                      },
                      type: 'card'
                    },
                    receipt_email: nil,
                    receipt_number: nil,
                    receipt_url: 'https://pay.stripe.com/receipts/acct_1KEAd7DFyWwdfZQ1/ch_3Kf5vdDFyWwdfZQ10hH9aseO/rcpt_LLnXrCd4Pwqn3qwEg3SOO3J8aWu7A45',
                    refunded: false,
                    refunds: {
                      object: 'list',
                      data: [],
                      has_more: false,
                      total_count: 0,
                      url: '/v1/charges/ch_3Kf5vdDFyWwdfZQ10hH9aseO/refunds'
                    },
                    review: nil,
                    shipping: nil,
                    source: nil,
                    source_transfer: nil,
                    statement_descriptor_suffix: order.number,
                    status: 'succeeded',
                    transfer_data: nil,
                    transfer_group: order.number
                  }
                ],
                has_more: false,
                total_count: 1,
                url: '/v1/charges?payment_intent=pi_3Kf5vdDFyWwdfZQ10kAY6fo0'
              },
              client_secret: 'pi_3Kf5vdDFyWwdfZQ10kAY6fo0_secret_yYf6XgXVVQ00ahNGz02f4FNAx',
              confirmation_method: 'automatic',
              created: 1_647_710_341,
              currency: 'usd',
              customer: nil,
              description: nil,
              invoice: nil,
              last_payment_error: nil,
              livemode: false,
              metadata: {
                spree_order_id: order.id
              },
              next_action: nil,
              on_behalf_of: nil,
              payment_method: 'pm_1Kf5w9DFyWwdfZQ1ofFYsuxi',
              payment_method_options: {
                card: {
                  installments: nil,
                  mandate_options: nil,
                  network: nil,
                  request_three_d_secure: 'automatic'
                }
              },
              payment_method_types: [
                'card'
              ],
              processing: nil,
              receipt_email: nil,
              review: nil,
              setup_future_usage: nil,
              shipping: nil,
              source: nil,
              statement_descriptor_suffix: order.number,
              status: 'succeeded',
              transfer_data: nil,
              transfer_group: order.number
            }
          }
        }
      )
    end

    it 'enqueues the complete order job' do
      expect { subject }.to have_enqueued_job(SpreeStripe::CompleteOrderJob).with(payment_intent.id)
    end
  end
end
