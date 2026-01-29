# frozen_string_literal: true

# Migration to create brands table for tracking brands within workspaces
class CreateBrands < ActiveRecord::Migration[8.1]
  def up
    # Drop table if it exists (for idempotency in development)
    # This will cascade and remove all associated indexes and constraints
    drop_table :brands, if_exists: true, force: :cascade

    # Manually drop any orphaned indexes that might exist
    execute "DROP INDEX IF EXISTS index_brands_on_workspace_id"
    execute "DROP INDEX IF EXISTS index_brands_on_workspace_and_name"
    execute "DROP INDEX IF EXISTS index_brands_on_domain"
    execute "DROP INDEX IF EXISTS index_brands_on_active"
    execute "DROP INDEX IF EXISTS index_brands_on_created_at"

    create_table :brands, id: :uuid do |t|
      t.references :workspace, type: :uuid, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.string :domain
      t.text :description
      t.jsonb :metadata, default: {}, null: false
      t.boolean :active, default: true, null: false
      t.integer :mentions_count, default: 0, null: false

      t.timestamps
    end

    # Add indexes separately
    add_index :brands, [ :workspace_id, :name ], unique: true, name: "index_brands_on_workspace_and_name"
    add_index :brands, :workspace_id
    add_index :brands, :domain
    add_index :brands, :active
    add_index :brands, :created_at
  end

  def down
    drop_table :brands, if_exists: true, force: :cascade
  end
end
