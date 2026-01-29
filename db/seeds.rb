# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database..."

# ============================================================================
# USERS
# ============================================================================
puts "\n👤 Creating users..."

# Create demo users with confirmed accounts
demo_owner = User.find_or_create_by!(email: "owner@example.com") do |user|
  user.first_name = "Alice"
  user.last_name = "Owner"
  user.password = "password123"
  user.password_confirmation = "password123"
  user.confirmed_at = Time.current
end
puts "  ✓ Created owner: #{demo_owner.email}"

demo_admin = User.find_or_create_by!(email: "admin@example.com") do |user|
  user.first_name = "Bob"
  user.last_name = "Admin"
  user.password = "password123"
  user.password_confirmation = "password123"
  user.confirmed_at = Time.current
end
puts "  ✓ Created admin: #{demo_admin.email}"

demo_editor = User.find_or_create_by!(email: "editor@example.com") do |user|
  user.first_name = "Charlie"
  user.last_name = "Editor"
  user.password = "password123"
  user.password_confirmation = "password123"
  user.confirmed_at = Time.current
end
puts "  ✓ Created editor: #{demo_editor.email}"

demo_viewer = User.find_or_create_by!(email: "viewer@example.com") do |user|
  user.first_name = "Diana"
  user.last_name = "Viewer"
  user.password = "password123"
  user.password_confirmation = "password123"
  user.confirmed_at = Time.current
end
puts "  ✓ Created viewer: #{demo_viewer.email}"

# ============================================================================
# WORKSPACES
# ============================================================================
puts "\n🏢 Creating workspaces..."

# Workspace 1: Tech Startup
tech_workspace = Workspace.find_or_create_by!(slug: "tech-startup") do |workspace|
  workspace.name = "Tech Startup"
  workspace.settings = {
    "timezone" => "America/Los_Angeles",
    "notifications_enabled" => true,
    "theme" => "light"
  }
end
puts "  ✓ Created workspace: #{tech_workspace.name}"

# Workspace 2: Marketing Agency
marketing_workspace = Workspace.find_or_create_by!(slug: "marketing-agency") do |workspace|
  workspace.name = "Marketing Agency"
  workspace.settings = {
    "timezone" => "America/New_York",
    "notifications_enabled" => true,
    "theme" => "dark"
  }
end
puts "  ✓ Created workspace: #{marketing_workspace.name}"

# ============================================================================
# WORKSPACE MEMBERSHIPS
# ============================================================================
puts "\n👥 Creating workspace memberships..."

# Tech Startup memberships
WorkspaceMembership.find_or_create_by!(workspace: tech_workspace, user: demo_owner) do |membership|
  membership.role = "owner"
end
puts "  ✓ Added #{demo_owner.full_name} as owner to #{tech_workspace.name}"

WorkspaceMembership.find_or_create_by!(workspace: tech_workspace, user: demo_admin) do |membership|
  membership.role = "admin"
end
puts "  ✓ Added #{demo_admin.full_name} as admin to #{tech_workspace.name}"

WorkspaceMembership.find_or_create_by!(workspace: tech_workspace, user: demo_editor) do |membership|
  membership.role = "editor"
end
puts "  ✓ Added #{demo_editor.full_name} as editor to #{tech_workspace.name}"

# Marketing Agency memberships
WorkspaceMembership.find_or_create_by!(workspace: marketing_workspace, user: demo_admin) do |membership|
  membership.role = "owner"
end
puts "  ✓ Added #{demo_admin.full_name} as owner to #{marketing_workspace.name}"

WorkspaceMembership.find_or_create_by!(workspace: marketing_workspace, user: demo_viewer) do |membership|
  membership.role = "viewer"
end
puts "  ✓ Added #{demo_viewer.full_name} as viewer to #{marketing_workspace.name}"

# ============================================================================
# BRANDS
# ============================================================================
puts "\n🏷️  Creating brands..."

# Tech Startup brands
tech_brands = [
  {
    name: "Acme SaaS",
    domain: "acmesaas.com",
    description: "Cloud-based project management platform for modern teams",
    metadata: {
      "industry" => "Technology",
      "keywords" => [ "saas", "project management", "collaboration", "cloud" ],
      "created_by" => "seed"
    },
    active: true
  },
  {
    name: "DevTools Pro",
    domain: "devtools.io",
    description: "Developer productivity tools and IDE extensions",
    metadata: {
      "industry" => "Technology",
      "keywords" => [ "developer tools", "ide", "productivity", "coding" ],
      "created_by" => "seed"
    },
    active: true
  },
  {
    name: "CloudSync",
    domain: "cloudsync.app",
    description: "Real-time file synchronization and backup service",
    metadata: {
      "industry" => "Technology",
      "keywords" => [ "cloud storage", "backup", "sync", "files" ],
      "created_by" => "seed"
    },
    active: false
  }
]

ActsAsTenant.with_tenant(tech_workspace) do
  tech_brands.each do |brand_attrs|
    brand = Brand.find_or_create_by!(workspace: tech_workspace, name: brand_attrs[:name]) do |b|
      b.domain = brand_attrs[:domain]
      b.description = brand_attrs[:description]
      b.metadata = brand_attrs[:metadata]
      b.active = brand_attrs[:active]
    end
    puts "  ✓ Created brand: #{brand.name} (#{brand.active ? 'active' : 'inactive'})"
  end
end

# Marketing Agency brands
marketing_brands = [
  {
    name: "BrandBoost",
    domain: "brandboost.marketing",
    description: "Full-service digital marketing agency specializing in brand growth",
    metadata: {
      "industry" => "Marketing",
      "keywords" => [ "digital marketing", "branding", "seo", "social media" ],
      "created_by" => "seed"
    },
    active: true
  },
  {
    name: "ContentCraft",
    domain: "contentcraft.co",
    description: "Content creation and strategy for B2B companies",
    metadata: {
      "industry" => "Marketing",
      "keywords" => [ "content marketing", "copywriting", "b2b", "strategy" ],
      "created_by" => "seed"
    },
    active: true
  }
]

ActsAsTenant.with_tenant(marketing_workspace) do
  marketing_brands.each do |brand_attrs|
    brand = Brand.find_or_create_by!(workspace: marketing_workspace, name: brand_attrs[:name]) do |b|
      b.domain = brand_attrs[:domain]
      b.description = brand_attrs[:description]
      b.metadata = brand_attrs[:metadata]
      b.active = brand_attrs[:active]
    end
    puts "  ✓ Created brand: #{brand.name} (#{brand.active ? 'active' : 'inactive'})"
  end
end

# ============================================================================
# SUMMARY
# ============================================================================
puts "\n" + "=" * 80
puts "✅ Seeding complete!"
puts "=" * 80
puts "\n📊 Summary:"
puts "  • Users: #{User.count}"
puts "  • Workspaces: #{Workspace.count}"
puts "  • Workspace Memberships: #{WorkspaceMembership.count}"

# Count brands across all workspaces
total_brands = ActsAsTenant.without_tenant { Brand.count }
active_brands = ActsAsTenant.without_tenant { Brand.where(active: true).count }
inactive_brands = ActsAsTenant.without_tenant { Brand.where(active: false).count }
puts "  • Brands: #{total_brands} (#{active_brands} active, #{inactive_brands} inactive)"
puts "\n🔑 Demo Credentials:"
puts "  • Owner:  owner@example.com / password123"
puts "  • Admin:  admin@example.com / password123"
puts "  • Editor: editor@example.com / password123"
puts "  • Viewer: viewer@example.com / password123"
puts "\n💡 All demo users are already confirmed and ready to use!"
puts "=" * 80
