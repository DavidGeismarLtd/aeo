# frozen_string_literal: true

# Migration to create workspace_memberships join table with role-based access
class CreateWorkspaceMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :workspace_memberships, id: :uuid do |t|
      t.references :workspace, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :role, null: false, default: "viewer"

      t.timestamps

      # Indexes
      t.index [ :workspace_id, :user_id ], unique: true, name: "index_workspace_memberships_on_workspace_and_user"
      t.index :role
      t.index :created_at
    end

    # Add check constraint for valid roles
    add_check_constraint :workspace_memberships,
                        "role IN ('owner', 'admin', 'editor', 'viewer')",
                        name: "workspace_memberships_role_check"
  end
end
