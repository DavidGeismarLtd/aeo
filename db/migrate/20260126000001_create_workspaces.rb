# frozen_string_literal: true

# Migration to create workspaces table for multi-tenancy
class CreateWorkspaces < ActiveRecord::Migration[8.1]
  def change
    create_table :workspaces, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.jsonb :settings, default: {}, null: false

      t.timestamps

      # Indexes
      t.index :slug, unique: true
      t.index :created_at
    end
  end
end
