class AddFingerprintToSpreeCreditCards < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_credit_cards, :fingerprint, :string
    add_index :spree_credit_cards, [:user_id, :fingerprint]
  end
end
