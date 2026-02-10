# frozen_string_literal: true

# Configure acts_as_tenant gem for multi-tenancy
# This ensures all workspace-scoped resources are automatically filtered by the current workspace
ActsAsTenant.configure do |config|
  # Require tenant to be set for all requests
  # This prevents accidentally querying without a tenant (safety feature)
  config.require_tenant = true

  # Specify the primary key column name
  config.pkey = :id
end
