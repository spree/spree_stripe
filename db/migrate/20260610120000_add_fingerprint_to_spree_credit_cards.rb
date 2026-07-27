class AddFingerprintToSpreeCreditCards < ActiveRecord::Migration[7.2]
  INDEX_NAME = 'index_spree_credit_cards_unique_fingerprint'.freeze

  # spree >= 5.6.0 ships this same migration in core (same name, so Rails' migration
  # installer skips this copy). On spree < 5.6.0 it runs here, giving the gateway a
  # place to store Stripe's card fingerprint for dedup. Guarded so it stays a no-op
  # if the column/index already exist.
  def up
    add_column :spree_credit_cards, :fingerprint, :string, if_not_exists: true

    return if index_name_exists?(:spree_credit_cards, INDEX_NAME)

    # Prevent duplicate saved cards (same gateway fingerprint + expiry) per user and
    # payment method at the database level. Only active, fingerprinted cards are
    # constrained, so legacy/non-gateway cards (NULL fingerprint) and soft-deleted
    # rows are left untouched.
    if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
      # MySQL has no partial indexes, but treats NULL as distinct in unique indexes,
      # so NULL fingerprints are naturally allowed. COALESCE on deleted_at keeps
      # soft-deleted rows from colliding with active ones.
      execute <<-SQL
        CREATE UNIQUE INDEX #{INDEX_NAME}
        ON spree_credit_cards(
          user_id,
          payment_method_id,
          fingerprint,
          month,
          year,
          (COALESCE(deleted_at, CAST('1970-01-01' AS DATETIME)))
        )
      SQL
    else
      add_index :spree_credit_cards, [:user_id, :payment_method_id, :fingerprint, :month, :year],
                unique: true,
                where: 'fingerprint IS NOT NULL AND deleted_at IS NULL',
                name: INDEX_NAME
    end
  end

  def down
    remove_index :spree_credit_cards, name: INDEX_NAME if index_name_exists?(:spree_credit_cards, INDEX_NAME)
    remove_column :spree_credit_cards, :fingerprint if column_exists?(:spree_credit_cards, :fingerprint)
  end
end
