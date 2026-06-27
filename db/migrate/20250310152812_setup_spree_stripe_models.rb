class SetupSpreeStripeModels < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_stripe_webhook_keys do |t|
      t.string :stripe_id, null: false
      t.string :signing_secret, null: false

      t.timestamps

      t.index ['signing_secret'], name: 'index_spree_stripe_webhook_keys_on_signing_secret', unique: true
      t.index ['stripe_id'], name: 'index_spree_stripe_webhook_keys_on_stripe_id', unique: true
    end

    create_table :spree_stripe_payment_methods_webhook_keys do |t|
      t.bigint :payment_method_id, null: false
      t.bigint :webhook_key_id, null: false

      t.timestamps

      t.index ['payment_method_id', 'webhook_key_id'], name: 'index_payment_method_id_webhook_key_id_uniqueness', unique: true
      t.index ['payment_method_id'], name: 'index_payment_methods_webhook_keys_on_payment_method_id'
      t.index ['webhook_key_id'], name: 'index_payment_methods_webhook_keys_on_webhook_key_id'
    end
  end
end
