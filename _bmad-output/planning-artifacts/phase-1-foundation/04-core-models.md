# Task 1.2: Core Database Models

**Status:** Not Started  
**Estimated Time:** 8 hours  
**Priority:** High  
**Dependencies:** Task 1.1 (Rails Setup & Configuration)

---

## 📋 Overview

Create the foundational database models for the AEO platform: **Workspace**, **WorkspaceMembership**, and **Brand**. These models form the core multi-tenancy architecture where workspaces contain brands and users have role-based access through memberships.

---

## 🎯 Objectives

1. Create three core models with UUID primary keys
2. Implement comprehensive associations, validations, and scopes
3. Set up role-based access control through WorkspaceMembership
4. Add slug generation for Workspace
5. Include JSONB fields for flexible metadata
6. Create complete factory definitions for testing
7. Write comprehensive RSpec model tests
8. Ensure all migrations run successfully

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Multi-Tenancy Model                      │
└─────────────────────────────────────────────────────────────┘

    User ──────┐
               │
               │ has_many :workspace_memberships
               │
               ▼
    WorkspaceMembership (Join Table with Roles)
               │
               │ belongs_to :workspace
               │ belongs_to :user
               │ role: owner, admin, editor, viewer
               │
               ▼
    Workspace ─────► has_many :brands
               │
               │ - name, slug
               │ - settings (JSONB)
               │ - UUID primary key
               │
               ▼
    Brand
               │
               │ - name, domain, description
               │ - metadata (JSONB)
               │ - active status
               │ - UUID primary key
```

---

## 📝 Detailed Requirements

### Model 1: Workspace

**Purpose:** Represents a tenant/organization in the multi-tenant architecture.

**Fields:**
- `id` (UUID, primary key)
- `name` (string, required) - Display name of the workspace
- `slug` (string, required, unique) - URL-friendly identifier
- `settings` (JSONB, default: {}) - Flexible configuration storage
- `timestamps` (created_at, updated_at)

**Associations:**
- `has_many :workspace_memberships, dependent: :destroy`
- `has_many :users, through: :workspace_memberships`
- `has_many :brands, dependent: :destroy`

**Validations:**
- Name presence
- Slug presence and uniqueness
- Slug format: lowercase letters, numbers, and hyphens only

**Callbacks:**
- Generate slug from name before validation on create

**Scopes:**
- `active` - Workspaces with at least one active brand
- `recent` - Ordered by created_at DESC

**Helper Methods:**
- `owner` - Returns the user with owner role
- `admins` - Returns all users with admin or owner role
- `member?(user)` - Check if user is a member
- `role_for(user)` - Get user's role in workspace

---

### Model 2: WorkspaceMembership

**Purpose:** Join table managing user access to workspaces with role-based permissions.

**Fields:**
- `id` (UUID, primary key)
- `workspace_id` (UUID, foreign key, required)
- `user_id` (UUID, foreign key, required)
- `role` (string, required, default: 'viewer')
- `timestamps` (created_at, updated_at)

**Associations:**
- `belongs_to :workspace`
- `belongs_to :user`

**Validations:**
- Workspace presence
- User presence
- Role inclusion in: ['owner', 'admin', 'editor', 'viewer']
- Uniqueness of user_id scoped to workspace_id
- Only one owner per workspace (custom validation)

**Scopes:**
- `owners` - Memberships with owner role
- `admins` - Memberships with admin role
- `editors` - Memberships with editor role
- `viewers` - Memberships with viewer role
- `by_role(role)` - Filter by specific role

**Helper Methods:**
- `owner?` - Check if role is owner
- `admin?` - Check if role is admin or owner
- `can_edit?` - Check if role is editor, admin, or owner
- `can_view?` - All roles can view

**Indexes:**
- Composite unique index on [workspace_id, user_id]
- Index on workspace_id
- Index on user_id
- Index on role

---

### Model 3: Brand

**Purpose:** Represents a brand/company being monitored within a workspace.

**Fields:**
- `id` (UUID, primary key)
- `workspace_id` (UUID, foreign key, required)
- `name` (string, required) - Brand name
- `domain` (string, optional) - Primary website domain
- `description` (text, optional) - Brand description
- `metadata` (JSONB, default: {}) - Flexible data (industry, keywords, etc.)
- `active` (boolean, default: true) - Whether brand is actively monitored
- `mentions_count` (integer, default: 0) - Counter cache for mentions
- `timestamps` (created_at, updated_at)

**Associations:**
- `belongs_to :workspace`

**Validations:**
- Workspace presence
- Name presence
- Name uniqueness scoped to workspace_id
- Domain format (if present) - valid domain pattern

**Scopes:**
- `active` - Where active = true
- `inactive` - Where active = false
- `recent` - Ordered by created_at DESC
- `by_workspace(workspace)` - Filter by workspace

**Helper Methods:**
- `activate!` - Set active to true
- `deactivate!` - Set active to false
- `toggle_active!` - Toggle active status

**Indexes:**
- Composite index on [workspace_id, name]
- Index on workspace_id
- Index on domain
- Index on active

---

## 🔧 Step-by-Step Implementation

### Step 1: Create Workspace Migration and Model

**Time Estimate:** 1.5 hours

#### 1.1 Generate Migration

```bash
rails generate migration CreateWorkspaces
```

#### 1.2 Edit Migration File

```ruby
# db/migrate/XXXXXX_create_workspaces.rb
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
```

#### 1.3 Create Workspace Model

```ruby
# app/models/workspace.rb
class Workspace < ApplicationRecord
  # Associations
  has_many :workspace_memberships, dependent: :destroy
  has_many :users, through: :workspace_memberships
  has_many :brands, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :slug, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, format: {
    with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
    message: "only allows lowercase letters, numbers, and hyphens (no leading/trailing hyphens)"
  }

  # Callbacks
  before_validation :generate_slug, on: :create, if: -> { slug.blank? }
  before_validation :normalize_slug

  # Scopes
  scope :active, -> { joins(:brands).where(brands: { active: true }).distinct }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_name, -> { order(:name) }

  # Instance Methods

  # Get the owner of this workspace
  def owner
    workspace_memberships.find_by(role: 'owner')&.user
  end

  # Get all admins (including owner)
  def admins
    users.joins(:workspace_memberships)
         .where(workspace_memberships: { workspace_id: id, role: ['owner', 'admin'] })
  end

  # Check if user is a member
  def member?(user)
    return false unless user
    workspace_memberships.exists?(user_id: user.id)
  end

  # Get user's role in this workspace
  def role_for(user)
    return nil unless user
    workspace_memberships.find_by(user_id: user.id)&.role
  end

  # Check if user has specific permission level
  def user_can_edit?(user)
    role = role_for(user)
    %w[owner admin editor].include?(role)
  end

  def user_can_admin?(user)
    role = role_for(user)
    %w[owner admin].include?(role)
  end

  private

  # Generate slug from name
  def generate_slug
    return if name.blank?

    base_slug = name.parameterize
    candidate_slug = base_slug
    counter = 1

    # Ensure uniqueness
    while Workspace.exists?(slug: candidate_slug)
      candidate_slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = candidate_slug
  end

  # Normalize slug to lowercase
  def normalize_slug
    self.slug = slug.downcase if slug.present?
  end
end
```

---

### Step 2: Create WorkspaceMembership Migration and Model

**Time Estimate:** 1.5 hours

#### 2.1 Generate Migration

```bash
rails generate migration CreateWorkspaceMemberships
```

#### 2.2 Edit Migration File

```ruby
# db/migrate/XXXXXX_create_workspace_memberships.rb
class CreateWorkspaceMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :workspace_memberships, id: :uuid do |t|
      t.references :workspace, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :role, null: false, default: 'viewer'

      t.timestamps

      # Indexes
      t.index [:workspace_id, :user_id], unique: true, name: 'index_workspace_memberships_on_workspace_and_user'
      t.index :role
      t.index :created_at
    end

    # Add check constraint for valid roles
    add_check_constraint :workspace_memberships,
                        "role IN ('owner', 'admin', 'editor', 'viewer')",
                        name: 'workspace_memberships_role_check'
  end
end
```

#### 2.3 Create WorkspaceMembership Model

```ruby
# app/models/workspace_membership.rb
class WorkspaceMembership < ApplicationRecord
  # Constants
  ROLES = %w[owner admin editor viewer].freeze

  # Associations
  belongs_to :workspace
  belongs_to :user

  # Validations
  validates :workspace, presence: true
  validates :user, presence: true
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :workspace_id, message: "is already a member of this workspace" }
  validate :only_one_owner_per_workspace, if: -> { role == 'owner' }

  # Callbacks
  after_create :send_membership_notification
  after_destroy :cleanup_workspace_if_empty

  # Scopes
  scope :owners, -> { where(role: 'owner') }
  scope :admins, -> { where(role: 'admin') }
  scope :editors, -> { where(role: 'editor') }
  scope :viewers, -> { where(role: 'viewer') }
  scope :by_role, ->(role) { where(role: role) if ROLES.include?(role.to_s) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance Methods

  # Role checks
  def owner?
    role == 'owner'
  end

  def admin?
    %w[owner admin].include?(role)
  end

  def can_edit?
    %w[owner admin editor].include?(role)
  end

  def can_view?
    true # All members can view
  end

  # Promote/demote role
  def promote!
    case role
    when 'viewer' then update!(role: 'editor')
    when 'editor' then update!(role: 'admin')
    when 'admin' then update!(role: 'owner')
    else
      false
    end
  end

  def demote!
    case role
    when 'owner' then update!(role: 'admin')
    when 'admin' then update!(role: 'editor')
    when 'editor' then update!(role: 'viewer')
    else
      false
    end
  end

  private

  # Ensure only one owner per workspace
  def only_one_owner_per_workspace
    if workspace && workspace.workspace_memberships.owners.where.not(id: id).exists?
      errors.add(:role, "workspace can only have one owner")
    end
  end

  # Send notification when user is added to workspace
  def send_membership_notification
    # TODO: Implement notification system
    # WorkspaceMembershipMailer.added_to_workspace(self).deliver_later
  end

  # Delete workspace if last member leaves
  def cleanup_workspace_if_empty
    workspace.destroy if workspace.workspace_memberships.empty?
  end
end
```

---

### Step 3: Create Brand Migration and Model

**Time Estimate:** 1.5 hours

#### 3.1 Generate Migration

```bash
rails generate migration CreateBrands
```

#### 3.2 Edit Migration File

```ruby
# db/migrate/XXXXXX_create_brands.rb
class CreateBrands < ActiveRecord::Migration[8.1]
  def change
    create_table :brands, id: :uuid do |t|
      t.references :workspace, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :domain
      t.text :description
      t.jsonb :metadata, default: {}, null: false
      t.boolean :active, default: true, null: false
      t.integer :mentions_count, default: 0, null: false

      t.timestamps

      # Indexes
      t.index [:workspace_id, :name], unique: true, name: 'index_brands_on_workspace_and_name'
      t.index :workspace_id
      t.index :domain
      t.index :active
      t.index :created_at
    end
  end
end
```

#### 3.3 Create Brand Model

**Note:** The `acts_as_tenant :workspace` line is commented out for now. You'll uncomment it in **Task 05: Multi-Tenancy Implementation** after configuring the `acts_as_tenant` gem. This gem will automatically scope all Brand queries to the current workspace.

```ruby
# app/models/brand.rb
class Brand < ApplicationRecord
  # Multi-tenancy (will be configured in Task 05)
  # acts_as_tenant :workspace

  # Associations
  belongs_to :workspace

  # Validations
  validates :workspace, presence: true
  validates :name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :name, uniqueness: { scope: :workspace_id, message: "already exists in this workspace" }
  validates :domain, format: {
    with: /\A(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]\z/i,
    message: "must be a valid domain name"
  }, allow_blank: true
  validates :description, length: { maximum: 1000 }, allow_blank: true

  # Callbacks
  before_validation :normalize_domain
  after_create :set_default_metadata

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_name, -> { order(:name) }
  scope :by_workspace, ->(workspace) { where(workspace: workspace) }
  scope :with_domain, -> { where.not(domain: nil) }

  # Instance Methods

  # Activate brand
  def activate!
    update!(active: true)
  end

  # Deactivate brand
  def deactivate!
    update!(active: false)
  end

  # Toggle active status
  def toggle_active!
    update!(active: !active)
  end

  # Get metadata value
  def get_metadata(key)
    metadata[key.to_s]
  end

  # Set metadata value
  def set_metadata(key, value)
    self.metadata = metadata.merge(key.to_s => value)
    save
  end

  # Common metadata helpers
  def industry
    get_metadata('industry')
  end

  def industry=(value)
    set_metadata('industry', value)
  end

  def keywords
    get_metadata('keywords') || []
  end

  def keywords=(value)
    set_metadata('keywords', Array(value))
  end

  private

  # Normalize domain to lowercase and remove protocol
  def normalize_domain
    return if domain.blank?

    self.domain = domain.downcase
                       .gsub(/^https?:\/\//, '')  # Remove protocol
                       .gsub(/^www\./, '')        # Remove www
                       .gsub(/\/$/, '')           # Remove trailing slash
  end

  # Set default metadata on creation
  def set_default_metadata
    self.metadata ||= {}
    self.metadata['created_by'] ||= 'system'
    self.metadata['keywords'] ||= []
    save if metadata_changed?
  end
end
```

---

### Step 4: Run Migrations

**Time Estimate:** 15 minutes

```bash
# Run all migrations
rails db:migrate

# Verify schema
rails db:schema:dump

# Check migration status
rails db:migrate:status
```

**Expected Output:**
```
== CreateWorkspaces: migrating ================================================
-- create_table(:workspaces, {:id=>:uuid})
   -> 0.0234s
== CreateWorkspaces: migrated (0.0235s) =======================================

== CreateWorkspaceMemberships: migrating ======================================
-- create_table(:workspace_memberships, {:id=>:uuid})
   -> 0.0189s
-- add_check_constraint(:workspace_memberships, "role IN ('owner', 'admin', 'editor', 'viewer')", {:name=>"workspace_memberships_role_check"})
   -> 0.0012s
== CreateWorkspaceMemberships: migrated (0.0202s) =============================

== CreateBrands: migrating ====================================================
-- create_table(:brands, {:id=>:uuid})
   -> 0.0156s
== CreateBrands: migrated (0.0157s) ===========================================
```

---

### Step 5: Create Factory Definitions

**Time Estimate:** 1 hour

#### 5.1 Create Workspace Factory

```ruby
# spec/factories/workspaces.rb
FactoryBot.define do
  factory :workspace do
    name { Faker::Company.name }
    settings { {} }

    # Traits
    trait :with_owner do
      after(:create) do |workspace|
        create(:workspace_membership, :owner, workspace: workspace)
      end
    end

    trait :with_team do
      after(:create) do |workspace|
        create(:workspace_membership, :owner, workspace: workspace)
        create(:workspace_membership, :admin, workspace: workspace)
        create(:workspace_membership, :editor, workspace: workspace)
        create(:workspace_membership, :viewer, workspace: workspace)
      end
    end

    trait :with_brands do
      after(:create) do |workspace|
        create_list(:brand, 3, workspace: workspace)
      end
    end

    trait :with_custom_slug do
      sequence(:slug) { |n| "workspace-#{n}" }
    end
  end
end
```

#### 5.2 Create WorkspaceMembership Factory

```ruby
# spec/factories/workspace_memberships.rb
FactoryBot.define do
  factory :workspace_membership do
    workspace
    user
    role { 'viewer' }

    # Traits for each role
    trait :owner do
      role { 'owner' }
    end

    trait :admin do
      role { 'admin' }
    end

    trait :editor do
      role { 'editor' }
    end

    trait :viewer do
      role { 'viewer' }
    end
  end
end
```

#### 5.3 Create Brand Factory

```ruby
# spec/factories/brands.rb
FactoryBot.define do
  factory :brand do
    workspace
    name { Faker::Company.name }
    domain { Faker::Internet.domain_name }
    description { Faker::Company.catch_phrase }
    metadata { { industry: 'Technology', product_category: 'SaaS' } }
    active { true }

    # Traits
    trait :inactive do
      active { false }
    end

    trait :with_keywords do
      metadata do
        {
          industry: 'Technology',
          keywords: ['AI', 'Machine Learning', 'Analytics']
        }
      end
    end

    trait :without_domain do
      domain { nil }
    end

    trait :with_mentions do
      mentions_count { rand(10..100) }
    end
  end
end
```

#### 5.4 Create User Factory (if not exists)

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    password_confirmation { 'password123' }

    trait :confirmed do
      confirmed_at { Time.current }
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end
  end
end
```

---

### Step 6: Create Model Tests with RSpec

**Time Estimate:** 2 hours

#### 6.1 Workspace Model Tests

```ruby
# spec/models/workspace_spec.rb
require 'rails_helper'

RSpec.describe Workspace, type: :model do
  describe 'associations' do
    it { should have_many(:workspace_memberships).dependent(:destroy) }
    it { should have_many(:users).through(:workspace_memberships) }
    it { should have_many(:brands).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:workspace) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_least(2).is_at_most(100) }
    it { should validate_presence_of(:slug) }
    it { should validate_uniqueness_of(:slug).case_insensitive }

    it 'validates slug format' do
      workspace = build(:workspace, slug: 'Invalid_Slug!')
      expect(workspace).not_to be_valid
      expect(workspace.errors[:slug]).to include(/only allows lowercase/)
    end

    it 'allows valid slug format' do
      workspace = build(:workspace, slug: 'valid-slug-123')
      expect(workspace).to be_valid
    end
  end

  describe 'callbacks' do
    describe '#generate_slug' do
      it 'generates slug from name on create' do
        workspace = create(:workspace, name: 'My Awesome Company')
        expect(workspace.slug).to eq('my-awesome-company')
      end

      it 'ensures slug uniqueness' do
        create(:workspace, name: 'Test Company')
        workspace2 = create(:workspace, name: 'Test Company')
        expect(workspace2.slug).to eq('test-company-1')
      end

      it 'does not override manually set slug' do
        workspace = create(:workspace, name: 'Test', slug: 'custom-slug')
        expect(workspace.slug).to eq('custom-slug')
      end
    end

    describe '#normalize_slug' do
      it 'converts slug to lowercase' do
        workspace = create(:workspace, slug: 'UPPERCASE')
        expect(workspace.slug).to eq('uppercase')
      end
    end
  end

  describe 'scopes' do
    describe '.active' do
      it 'returns workspaces with active brands' do
        workspace_with_active = create(:workspace, :with_brands)
        workspace_without_brands = create(:workspace)

        expect(Workspace.active).to include(workspace_with_active)
        expect(Workspace.active).not_to include(workspace_without_brands)
      end
    end

    describe '.recent' do
      it 'orders by created_at descending' do
        old_workspace = create(:workspace, created_at: 2.days.ago)
        new_workspace = create(:workspace, created_at: 1.day.ago)

        expect(Workspace.recent.first).to eq(new_workspace)
        expect(Workspace.recent.last).to eq(old_workspace)
      end
    end
  end

  describe 'instance methods' do
    let(:workspace) { create(:workspace) }
    let(:owner_user) { create(:user) }
    let(:admin_user) { create(:user) }
    let(:editor_user) { create(:user) }

    before do
      create(:workspace_membership, :owner, workspace: workspace, user: owner_user)
      create(:workspace_membership, :admin, workspace: workspace, user: admin_user)
      create(:workspace_membership, :editor, workspace: workspace, user: editor_user)
    end

    describe '#owner' do
      it 'returns the owner user' do
        expect(workspace.owner).to eq(owner_user)
      end
    end

    describe '#admins' do
      it 'returns owner and admin users' do
        admins = workspace.admins
        expect(admins).to include(owner_user, admin_user)
        expect(admins).not_to include(editor_user)
      end
    end

    describe '#member?' do
      it 'returns true for members' do
        expect(workspace.member?(owner_user)).to be true
      end

      it 'returns false for non-members' do
        non_member = create(:user)
        expect(workspace.member?(non_member)).to be false
      end

      it 'returns false for nil user' do
        expect(workspace.member?(nil)).to be false
      end
    end

    describe '#role_for' do
      it 'returns user role' do
        expect(workspace.role_for(owner_user)).to eq('owner')
        expect(workspace.role_for(admin_user)).to eq('admin')
      end

      it 'returns nil for non-members' do
        non_member = create(:user)
        expect(workspace.role_for(non_member)).to be_nil
      end
    end

    describe '#user_can_edit?' do
      it 'returns true for owner, admin, editor' do
        expect(workspace.user_can_edit?(owner_user)).to be true
        expect(workspace.user_can_edit?(admin_user)).to be true
        expect(workspace.user_can_edit?(editor_user)).to be true
      end

      it 'returns false for viewer' do
        viewer = create(:user)
        create(:workspace_membership, :viewer, workspace: workspace, user: viewer)
        expect(workspace.user_can_edit?(viewer)).to be false
      end
    end
  end
end
```

#### 6.2 WorkspaceMembership Model Tests

```ruby
# spec/models/workspace_membership_spec.rb
require 'rails_helper'

RSpec.describe WorkspaceMembership, type: :model do
  describe 'associations' do
    it { should belong_to(:workspace) }
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:workspace_membership) }

    it { should validate_presence_of(:workspace) }
    it { should validate_presence_of(:user) }
    it { should validate_presence_of(:role) }
    it { should validate_inclusion_of(:role).in_array(WorkspaceMembership::ROLES) }

    it 'validates uniqueness of user per workspace' do
      membership = create(:workspace_membership)
      duplicate = build(:workspace_membership,
                       workspace: membership.workspace,
                       user: membership.user)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include(/already a member/)
    end

    describe 'only one owner per workspace' do
      let(:workspace) { create(:workspace) }

      it 'allows first owner' do
        membership = build(:workspace_membership, :owner, workspace: workspace)
        expect(membership).to be_valid
      end

      it 'prevents second owner' do
        create(:workspace_membership, :owner, workspace: workspace)
        second_owner = build(:workspace_membership, :owner, workspace: workspace)

        expect(second_owner).not_to be_valid
        expect(second_owner.errors[:role]).to include(/only have one owner/)
      end
    end
  end

  describe 'scopes' do
    let!(:owner) { create(:workspace_membership, :owner) }
    let!(:admin) { create(:workspace_membership, :admin) }
    let!(:editor) { create(:workspace_membership, :editor) }
    let!(:viewer) { create(:workspace_membership, :viewer) }

    it '.owners returns only owners' do
      expect(WorkspaceMembership.owners).to eq([owner])
    end

    it '.admins returns only admins' do
      expect(WorkspaceMembership.admins).to eq([admin])
    end

    it '.editors returns only editors' do
      expect(WorkspaceMembership.editors).to eq([editor])
    end

    it '.viewers returns only viewers' do
      expect(WorkspaceMembership.viewers).to eq([viewer])
    end

    it '.by_role filters by role' do
      expect(WorkspaceMembership.by_role('owner')).to eq([owner])
      expect(WorkspaceMembership.by_role('invalid')).to be_empty
    end
  end

  describe 'instance methods' do
    describe 'role checks' do
      it '#owner? returns true for owner' do
        membership = build(:workspace_membership, :owner)
        expect(membership.owner?).to be true
      end

      it '#admin? returns true for owner and admin' do
        owner = build(:workspace_membership, :owner)
        admin = build(:workspace_membership, :admin)
        editor = build(:workspace_membership, :editor)

        expect(owner.admin?).to be true
        expect(admin.admin?).to be true
        expect(editor.admin?).to be false
      end

      it '#can_edit? returns true for owner, admin, editor' do
        owner = build(:workspace_membership, :owner)
        admin = build(:workspace_membership, :admin)
        editor = build(:workspace_membership, :editor)
        viewer = build(:workspace_membership, :viewer)

        expect(owner.can_edit?).to be true
        expect(admin.can_edit?).to be true
        expect(editor.can_edit?).to be true
        expect(viewer.can_edit?).to be false
      end

      it '#can_view? returns true for all roles' do
        WorkspaceMembership::ROLES.each do |role|
          membership = build(:workspace_membership, role: role)
          expect(membership.can_view?).to be true
        end
      end
    end

    describe '#promote!' do
      it 'promotes viewer to editor' do
        membership = create(:workspace_membership, :viewer)
        membership.promote!
        expect(membership.reload.role).to eq('editor')
      end

      it 'promotes editor to admin' do
        membership = create(:workspace_membership, :editor)
        membership.promote!
        expect(membership.reload.role).to eq('admin')
      end
    end

    describe '#demote!' do
      it 'demotes admin to editor' do
        membership = create(:workspace_membership, :admin)
        membership.demote!
        expect(membership.reload.role).to eq('editor')
      end

      it 'demotes editor to viewer' do
        membership = create(:workspace_membership, :editor)
        membership.demote!
        expect(membership.reload.role).to eq('viewer')
      end
    end
  end
end
```

#### 6.3 Brand Model Tests

```ruby
# spec/models/brand_spec.rb
require 'rails_helper'

RSpec.describe Brand, type: :model do
  describe 'associations' do
    it { should belong_to(:workspace) }
  end

  describe 'validations' do
    subject { build(:brand) }

    it { should validate_presence_of(:workspace) }
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_least(1).is_at_most(100) }
    it { should validate_length_of(:description).is_at_most(1000) }

    it 'validates name uniqueness within workspace' do
      brand = create(:brand, name: 'Test Brand')
      duplicate = build(:brand,
                       workspace: brand.workspace,
                       name: 'Test Brand')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include(/already exists/)
    end

    it 'allows same name in different workspaces' do
      brand1 = create(:brand, name: 'Test Brand')
      brand2 = build(:brand, name: 'Test Brand') # Different workspace

      expect(brand2).to be_valid
    end

    describe 'domain validation' do
      it 'accepts valid domains' do
        valid_domains = ['example.com', 'sub.example.com', 'example.co.uk']

        valid_domains.each do |domain|
          brand = build(:brand, domain: domain)
          expect(brand).to be_valid, "#{domain} should be valid"
        end
      end

      it 'rejects invalid domains' do
        invalid_domains = ['not a domain', 'http://example.com', '-invalid.com']

        invalid_domains.each do |domain|
          brand = build(:brand, domain: domain)
          expect(brand).not_to be_valid, "#{domain} should be invalid"
        end
      end

      it 'allows blank domain' do
        brand = build(:brand, domain: nil)
        expect(brand).to be_valid
      end
    end
  end

  describe 'callbacks' do
    describe '#normalize_domain' do
      it 'removes http protocol' do
        brand = create(:brand, domain: 'http://example.com')
        expect(brand.domain).to eq('example.com')
      end

      it 'removes https protocol' do
        brand = create(:brand, domain: 'https://example.com')
        expect(brand.domain).to eq('example.com')
      end

      it 'removes www prefix' do
        brand = create(:brand, domain: 'www.example.com')
        expect(brand.domain).to eq('example.com')
      end

      it 'removes trailing slash' do
        brand = create(:brand, domain: 'example.com/')
        expect(brand.domain).to eq('example.com')
      end

      it 'converts to lowercase' do
        brand = create(:brand, domain: 'EXAMPLE.COM')
        expect(brand.domain).to eq('example.com')
      end
    end

    describe '#set_default_metadata' do
      it 'sets default metadata on create' do
        brand = create(:brand)
        expect(brand.metadata['created_by']).to eq('system')
        expect(brand.metadata['keywords']).to eq([])
      end
    end
  end

  describe 'scopes' do
    let!(:active_brand) { create(:brand, active: true) }
    let!(:inactive_brand) { create(:brand, active: false) }

    describe '.active' do
      it 'returns only active brands' do
        expect(Brand.active).to include(active_brand)
        expect(Brand.active).not_to include(inactive_brand)
      end
    end

    describe '.inactive' do
      it 'returns only inactive brands' do
        expect(Brand.inactive).to include(inactive_brand)
        expect(Brand.inactive).not_to include(active_brand)
      end
    end

    describe '.recent' do
      it 'orders by created_at descending' do
        old_brand = create(:brand, created_at: 2.days.ago)
        new_brand = create(:brand, created_at: 1.day.ago)

        expect(Brand.recent.first).to eq(new_brand)
        expect(Brand.recent.last).to eq(old_brand)
      end
    end

    describe '.by_workspace' do
      it 'filters by workspace' do
        workspace = create(:workspace)
        brand = create(:brand, workspace: workspace)
        other_brand = create(:brand)

        expect(Brand.by_workspace(workspace)).to include(brand)
        expect(Brand.by_workspace(workspace)).not_to include(other_brand)
      end
    end

    describe '.with_domain' do
      it 'returns brands with domain set' do
        with_domain = create(:brand, domain: 'example.com')
        without_domain = create(:brand, domain: nil)

        expect(Brand.with_domain).to include(with_domain)
        expect(Brand.with_domain).not_to include(without_domain)
      end
    end
  end

  describe 'instance methods' do
    let(:brand) { create(:brand) }

    describe '#activate!' do
      it 'sets active to true' do
        brand.update(active: false)
        brand.activate!
        expect(brand.reload.active).to be true
      end
    end

    describe '#deactivate!' do
      it 'sets active to false' do
        brand.update(active: true)
        brand.deactivate!
        expect(brand.reload.active).to be false
      end
    end

    describe '#toggle_active!' do
      it 'toggles active status' do
        original_status = brand.active
        brand.toggle_active!
        expect(brand.reload.active).to eq(!original_status)
      end
    end

    describe 'metadata helpers' do
      describe '#get_metadata and #set_metadata' do
        it 'gets and sets metadata values' do
          brand.set_metadata('custom_key', 'custom_value')
          expect(brand.get_metadata('custom_key')).to eq('custom_value')
        end
      end

      describe '#industry' do
        it 'gets and sets industry' do
          brand.industry = 'Technology'
          expect(brand.industry).to eq('Technology')
        end
      end

      describe '#keywords' do
        it 'gets and sets keywords array' do
          brand.keywords = ['AI', 'ML', 'Analytics']
          expect(brand.keywords).to eq(['AI', 'ML', 'Analytics'])
        end

        it 'returns empty array if not set' do
          brand.metadata = {}
          expect(brand.keywords).to eq([])
        end
      end
    end
  end
end
```

---

### Step 7: Configure RSpec and Test Setup

**Time Estimate:** 30 minutes

#### 7.1 Configure RSpec Rails Helper

```ruby
# spec/rails_helper.rb
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'factory_bot_rails'
require 'faker'

# Load support files
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Use transactional fixtures
  config.use_transactional_fixtures = true

  # Infer spec type from file location
  config.infer_spec_type_from_file_location!

  # Filter Rails backtrace
  config.filter_rails_from_backtrace!

  # Database cleaner configuration
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

# Shoulda Matchers configuration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

#### 7.2 Create Support Files

```ruby
# spec/support/factory_bot.rb
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Lint factories in development
  config.before(:suite) do
    if Rails.env.development?
      FactoryBot.lint(traits: true)
    end
  end
end
```

```ruby
# spec/support/database_cleaner.rb
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
```

---

### Step 8: Run Tests

**Time Estimate:** 15 minutes

```bash
# Run all model tests
bundle exec rspec spec/models

# Run specific model tests
bundle exec rspec spec/models/workspace_spec.rb
bundle exec rspec spec/models/workspace_membership_spec.rb
bundle exec rspec spec/models/brand_spec.rb

# Run with documentation format
bundle exec rspec spec/models --format documentation

# Run with coverage (if SimpleCov is configured)
COVERAGE=true bundle exec rspec spec/models
```

**Expected Output:**
```
Workspace
  associations
    should have many workspace_memberships dependent => destroy
    should have many users through workspace_memberships
    should have many brands dependent => destroy
  validations
    should validate that :name cannot be empty/falsy
    ...

Finished in 2.34 seconds (files took 1.23 seconds to load)
45 examples, 0 failures
```

---

## 📊 Database Schema Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DATABASE SCHEMA RELATIONSHIPS                    │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│       users          │
│──────────────────────│
│ id (UUID, PK)        │
│ email                │
│ password_digest      │
│ first_name           │
│ last_name            │
│ confirmed_at         │
│ created_at           │
│ updated_at           │
└──────────────────────┘
          │
          │ has_many :workspace_memberships
          │
          ▼
┌──────────────────────────────┐
│  workspace_memberships       │
│──────────────────────────────│
│ id (UUID, PK)                │
│ workspace_id (UUID, FK) ─────┼──────────┐
│ user_id (UUID, FK)           │          │
│ role (enum)                  │          │
│   - owner                    │          │
│   - admin                    │          │
│   - editor                   │          │
│   - viewer                   │          │
│ created_at                   │          │
│ updated_at                   │          │
│                              │          │
│ UNIQUE INDEX:                │          │
│   [workspace_id, user_id]    │          │
│ CHECK CONSTRAINT:            │          │
│   role IN (...)              │          │
└──────────────────────────────┘          │
                                          │
                                          │ belongs_to :workspace
                                          │
                                          ▼
                              ┌──────────────────────┐
                              │    workspaces        │
                              │──────────────────────│
                              │ id (UUID, PK)        │
                              │ name                 │
                              │ slug (UNIQUE)        │
                              │ settings (JSONB)     │
                              │ created_at           │
                              │ updated_at           │
                              └──────────────────────┘
                                          │
                                          │ has_many :brands
                                          │
                                          ▼
                              ┌──────────────────────┐
                              │       brands         │
                              │──────────────────────│
                              │ id (UUID, PK)        │
                              │ workspace_id (FK)    │
                              │ name                 │
                              │ domain               │
                              │ description          │
                              │ metadata (JSONB)     │
                              │ active               │
                              │ mentions_count       │
                              │ created_at           │
                              │ updated_at           │
                              │                      │
                              │ UNIQUE INDEX:        │
                              │   [workspace_id,     │
                              │    name]             │
                              └──────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                              KEY RELATIONSHIPS                           │
└─────────────────────────────────────────────────────────────────────────┘

1. User ←→ Workspace (Many-to-Many through WorkspaceMembership)
   - A user can belong to multiple workspaces
   - A workspace can have multiple users
   - WorkspaceMembership defines the role

2. Workspace → Brand (One-to-Many)
   - A workspace can have multiple brands
   - A brand belongs to exactly one workspace
   - Cascade delete: deleting workspace deletes all brands

3. WorkspaceMembership Constraints:
   - One user can only have one membership per workspace
   - Each workspace must have exactly one owner
   - Roles are enforced via database check constraint

┌─────────────────────────────────────────────────────────────────────────┐
│                           JSONB FIELD SCHEMAS                            │
└─────────────────────────────────────────────────────────────────────────┘

Workspace.settings (JSONB):
{
  "timezone": "UTC",
  "date_format": "YYYY-MM-DD",
  "notifications": {
    "email": true,
    "slack": false
  },
  "features": {
    "advanced_analytics": true,
    "api_access": true
  }
}

Brand.metadata (JSONB):
{
  "industry": "Technology",
  "product_category": "SaaS",
  "keywords": ["AI", "Machine Learning", "Analytics"],
  "target_audience": "B2B",
  "competitors": ["competitor1.com", "competitor2.com"],
  "created_by": "system",
  "custom_fields": {
    "field1": "value1"
  }
}
```

---

## ✅ Success Criteria Checklist

### Database & Migrations
- [ ] All three migrations created successfully
- [ ] Migrations use UUID primary keys
- [ ] All foreign keys properly defined with type: :uuid
- [ ] Unique indexes created on critical fields
- [ ] Check constraint added for WorkspaceMembership roles
- [ ] `rails db:migrate` runs without errors
- [ ] `rails db:rollback` works correctly
- [ ] Schema.rb reflects all changes accurately

### Models - Workspace
- [ ] Workspace model created with all associations
- [ ] Name and slug validations working
- [ ] Slug auto-generation from name works
- [ ] Slug uniqueness enforced
- [ ] Slug format validation passes
- [ ] Settings JSONB field accessible
- [ ] All scopes (active, recent) working
- [ ] Helper methods (owner, admins, member?, role_for) working
- [ ] Permission check methods working

### Models - WorkspaceMembership
- [ ] WorkspaceMembership model created with associations
- [ ] Role validation working (only valid roles accepted)
- [ ] Uniqueness validation (one membership per user per workspace)
- [ ] Only one owner per workspace validation working
- [ ] All role scopes working (owners, admins, etc.)
- [ ] Role check methods working (owner?, admin?, can_edit?)
- [ ] Promote/demote methods working correctly
- [ ] Callbacks executing properly

### Models - Brand
- [ ] Brand model created with workspace association
- [ ] Name validation and uniqueness (scoped to workspace) working
- [ ] Domain validation and normalization working
- [ ] Metadata JSONB field accessible
- [ ] Active/inactive scopes working
- [ ] Activate/deactivate methods working
- [ ] Metadata helper methods working (industry, keywords)
- [ ] Counter cache field (mentions_count) present

### Factories
- [ ] Workspace factory created with traits
- [ ] WorkspaceMembership factory created with role traits
- [ ] Brand factory created with traits
- [ ] User factory created (if needed)
- [ ] All factories generate valid records
- [ ] Factory traits working correctly
- [ ] `FactoryBot.lint` passes without errors

### Tests
- [ ] Workspace model tests passing (associations, validations, scopes, methods)
- [ ] WorkspaceMembership model tests passing
- [ ] Brand model tests passing
- [ ] All RSpec tests green (0 failures)
- [ ] Test coverage > 90% for model code
- [ ] Edge cases tested (nil values, invalid data, etc.)
- [ ] Callback behavior tested

### Integration
- [ ] Can create workspace with owner in one transaction
- [ ] Can add multiple members to workspace
- [ ] Can create brands within workspace
- [ ] Cascade deletes working (workspace → memberships, brands)
- [ ] Role-based access checks working
- [ ] JSONB fields can be queried and updated

### Documentation
- [ ] Model files have clear comments
- [ ] Complex validations documented
- [ ] Helper methods documented
- [ ] README updated with model information (if applicable)

---

## 🐛 Troubleshooting Guide

### Issue: Migration fails with "PG::UndefinedFunction: ERROR: type 'uuid' does not exist"

**Cause:** PostgreSQL pgcrypto extension not enabled.

**Solution:**
```bash
# Create and run migration to enable extension
rails generate migration EnablePgcryptoExtension

# In migration file:
class EnablePgcryptoExtension < ActiveRecord::Migration[8.1]
  def change
    enable_extension 'pgcrypto'
  end
end

rails db:migrate
```

---

### Issue: Slug validation fails with "only allows lowercase letters..."

**Cause:** Slug contains uppercase letters or invalid characters.

**Solution:**
The `normalize_slug` callback should handle this automatically. If it doesn't:
```ruby
# Ensure callback is running
before_validation :normalize_slug

# Or manually normalize:
workspace.slug = workspace.slug.downcase.parameterize
workspace.save
```

---

### Issue: "workspace can only have one owner" validation not working

**Cause:** Validation runs before record is persisted, or existing owner not found.

**Solution:**
```ruby
# Check if validation is properly defined:
validate :only_one_owner_per_workspace, if: -> { role == 'owner' }

# Ensure it checks for other owners excluding current record:
def only_one_owner_per_workspace
  if workspace && workspace.workspace_memberships.owners.where.not(id: id).exists?
    errors.add(:role, "workspace can only have one owner")
  end
end
```

---

### Issue: FactoryBot.lint fails with validation errors

**Cause:** Factories creating invalid data or conflicting records.

**Solution:**
```ruby
# Use sequences for unique fields
factory :workspace do
  sequence(:name) { |n| "Workspace #{n}" }
  # slug will be auto-generated
end

# Ensure associations are valid
factory :workspace_membership do
  workspace
  user
  role { 'viewer' } # Default to viewer, not owner
end
```

---

### Issue: Tests fail with "PG::UniqueViolation: duplicate key value"

**Cause:** Database not being cleaned between tests.

**Solution:**
```ruby
# Ensure DatabaseCleaner is configured in spec/rails_helper.rb
config.before(:suite) do
  DatabaseCleaner.clean_with(:truncation)
end

config.before(:each) do
  DatabaseCleaner.strategy = :transaction
  DatabaseCleaner.start
end

config.after(:each) do
  DatabaseCleaner.clean
end

# Or manually clean:
rails db:test:prepare
```

---

### Issue: JSONB fields not saving changes

**Cause:** Rails doesn't detect changes to JSONB fields automatically.

**Solution:**
```ruby
# Use will_save_change_to_attribute! to mark as changed
brand.metadata['new_key'] = 'value'
brand.metadata_will_change!
brand.save

# Or use merge to create new hash
brand.metadata = brand.metadata.merge('new_key' => 'value')
brand.save

# Or use the helper methods provided
brand.set_metadata('new_key', 'value') # Already handles this
```

---

### Issue: Domain validation rejects valid domains

**Cause:** Regex pattern too strict or domain has special characters.

**Solution:**
```ruby
# Update regex to be more permissive:
validates :domain, format: {
  with: /\A(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]\z/i,
  message: "must be a valid domain name"
}, allow_blank: true

# Or use a gem like 'public_suffix' for more robust validation
```

---

### Issue: Cascade delete not working (brands remain after workspace deleted)

**Cause:** Foreign key constraint not set with ON DELETE CASCADE.

**Solution:**
```ruby
# In migration, ensure foreign_key is set:
t.references :workspace, type: :uuid, null: false, foreign_key: true

# Or add manually:
add_foreign_key :brands, :workspaces, on_delete: :cascade

# In model, ensure dependent: :destroy is set:
has_many :brands, dependent: :destroy
```

---

### Issue: Role promotion/demotion creates duplicate owners

**Cause:** Validation not running on promote! method.

**Solution:**
```ruby
# Use update! instead of update to raise on validation errors:
def promote!
  case role
  when 'admin' then update!(role: 'owner')
  # ...
  end
rescue ActiveRecord::RecordInvalid => e
  # Handle validation error (e.g., duplicate owner)
  false
end
```

---

### Issue: Shoulda matchers not working in tests

**Cause:** Shoulda matchers not configured or not loaded.

**Solution:**
```ruby
# Add to Gemfile:
group :test do
  gem 'shoulda-matchers', '~> 6.4'
end

# Configure in spec/rails_helper.rb:
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

---

## 📚 Additional Resources

### Rails Guides
- [Active Record Associations](https://guides.rubyonrails.org/association_basics.html)
- [Active Record Validations](https://guides.rubyonrails.org/active_record_validations.html)
- [Active Record Callbacks](https://guides.rubyonrails.org/active_record_callbacks.html)
- [Active Record Migrations](https://guides.rubyonrails.org/active_record_migrations.html)

### Testing Resources
- [RSpec Rails Documentation](https://rspec.info/documentation/latest/rspec-rails/)
- [FactoryBot Getting Started](https://github.com/thoughtbot/factory_bot/blob/master/GETTING_STARTED.md)
- [Shoulda Matchers Documentation](https://github.com/thoughtbot/shoulda-matchers)

### PostgreSQL & JSONB
- [PostgreSQL JSONB Documentation](https://www.postgresql.org/docs/current/datatype-json.html)
- [Rails JSONB Guide](https://nandovieira.com/using-postgresql-and-jsonb-with-ruby-on-rails)

---

## 🎯 Next Steps

After completing this task, you should:

1. **Verify Everything Works:**
   ```bash
   rails db:migrate
   bundle exec rspec spec/models
   rails console
   # Test creating records manually
   ```

2. **Create Sample Data:**
   ```ruby
   # In rails console or seeds.rb
   workspace = Workspace.create!(name: "Test Company")
   user = User.create!(email: "test@example.com", password: "password123")
   WorkspaceMembership.create!(workspace: workspace, user: user, role: "owner")
   Brand.create!(workspace: workspace, name: "Test Brand", domain: "example.com")
   ```

3. **Move to Next Task:**
   - Task 1.3: User Authentication System
   - Or continue with additional models (AiPlatform, Mention, etc.)

4. **Optional Enhancements:**
   - Add model concerns for shared behavior
   - Implement audit logging for model changes
   - Add soft delete functionality
   - Create admin interface for managing models

---

## 📝 Notes

- All models use UUID primary keys for better scalability and security
- JSONB fields provide flexibility for future feature additions without migrations
- Role-based access control is enforced at both database and application levels
- Comprehensive test coverage ensures reliability
- Slug generation provides user-friendly URLs
- Cascade deletes maintain referential integrity

**Estimated Total Time:** 8 hours
**Actual Time:** __________ (fill in after completion)

---

**Task Status:** [ ] Not Started | [ ] In Progress | [ ] Completed | [ ] Blocked

**Completed By:** __________
**Completion Date:** __________
**Notes:** __________


