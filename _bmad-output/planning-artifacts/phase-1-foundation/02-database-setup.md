# Task 02: Database Setup & PostgreSQL Extensions

## Overview
Set up PostgreSQL database with essential extensions for the AEO (Augment Engineering Ops) platform. This task establishes the foundation for data persistence, UUID generation, text search capabilities, and key-value storage.

**Estimated Time:** 2 hours

---

## Prerequisites
- PostgreSQL 14+ installed locally
- Rails application initialized (Task 01 completed)
- Database user with SUPERUSER or CREATEDB privileges

---

## Objectives
1. Create development, test, and production databases
2. Enable essential PostgreSQL extensions
3. Configure database.yml for all environments
4. Verify database connectivity
5. Prepare infrastructure for future TimescaleDB integration

---

## Step-by-Step Instructions

### Step 1: Create PostgreSQL Database User (5 min)

```bash
# Connect to PostgreSQL as superuser
psql postgres

# Create database user
CREATE USER aeo_user WITH PASSWORD 'your_secure_password';
ALTER USER aeo_user CREATEDB;

# Grant necessary privileges
ALTER USER aeo_user WITH SUPERUSER;  # Required for enabling extensions

# Exit psql
\q
```

**Note:** In production, use environment variables for credentials and limit privileges appropriately.

### Step 2: Configure database.yml (10 min)

Update `config/database.yml`:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: aeo_user
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: <%= ENV.fetch("DATABASE_HOST") { "localhost" } %>
  port: <%= ENV.fetch("DATABASE_PORT") { 5432 } %>

development:
  <<: *default
  database: aeo_development

test:
  <<: *default
  database: aeo_test

production:
  <<: *default
  database: aeo_production
  username: <%= ENV['DATABASE_USERNAME'] %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: <%= ENV['DATABASE_HOST'] %>
```

### Step 3: Create .env File for Local Development (5 min)

Create `.env` in project root:

```bash
DATABASE_PASSWORD=your_secure_password
DATABASE_HOST=localhost
DATABASE_PORT=5432
```

Add to `.gitignore`:
```
.env
.env.local
```

### Step 4: Create Databases (5 min)

```bash
# Create all databases
rails db:create

# Verify databases were created
psql -U aeo_user -l | grep aeo
```

Expected output:
```
aeo_development
aeo_test
```

### Step 5: Create Migration for PostgreSQL Extensions (15 min)

Generate the migration:

```bash
rails generate migration EnablePostgresqlExtensions
```

Edit the migration file `db/migrate/YYYYMMDDHHMMSS_enable_postgresql_extensions.rb`:

```ruby
class EnablePostgresqlExtensions < ActiveRecord::Migration[7.1]
  def up
    # Enable pgcrypto for UUID generation
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    
    # Enable pg_trgm for fuzzy text search and similarity matching
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')
    
    # Enable hstore for key-value pair storage
    enable_extension 'hstore' unless extension_enabled?('hstore')
    
    # Output confirmation
    execute <<-SQL
      DO $$
      BEGIN
        RAISE NOTICE 'PostgreSQL extensions enabled successfully:';
        RAISE NOTICE '  - pgcrypto: UUID generation and cryptographic functions';
        RAISE NOTICE '  - pg_trgm: Trigram-based text search and similarity';
        RAISE NOTICE '  - hstore: Key-value storage in single column';
      END $$;
    SQL
  end

  def down
    # Disable extensions in reverse order
    disable_extension 'hstore' if extension_enabled?('hstore')
    disable_extension 'pg_trgm' if extension_enabled?('pg_trgm')
    disable_extension 'pgcrypto' if extension_enabled?('pgcrypto')
  end
end
```

### Step 6: Run Migration (5 min)

```bash
# Run migration for development
rails db:migrate

# Run migration for test environment
RAILS_ENV=test rails db:migrate

# Verify extensions are enabled
rails runner "puts ActiveRecord::Base.connection.execute('SELECT * FROM pg_extension').to_a"
```

### Step 7: Verify Extension Functionality (10 min)

Create a test script `scripts/verify_db_extensions.rb`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../config/environment'

puts "🔍 Verifying PostgreSQL Extensions...\n\n"

# Test pgcrypto - UUID generation
puts "1. Testing pgcrypto (UUID generation):"
uuid = ActiveRecord::Base.connection.execute("SELECT gen_random_uuid()").first['gen_random_uuid']
puts "   ✓ Generated UUID: #{uuid}\n\n"

# Test pg_trgm - Similarity search
puts "2. Testing pg_trgm (text similarity):"
similarity = ActiveRecord::Base.connection.execute(
  "SELECT similarity('hello', 'hallo') as score"
).first['score']
puts "   ✓ Similarity score between 'hello' and 'hallo': #{similarity}\n\n"

# Test hstore - Key-value storage
puts "3. Testing hstore (key-value storage):"
hstore_test = ActiveRecord::Base.connection.execute(
  "SELECT 'key1=>value1, key2=>value2'::hstore as data"
).first['data']
puts "   ✓ Hstore data: #{hstore_test}\n\n"

puts "✅ All PostgreSQL extensions are working correctly!"
```

Run the verification:
```bash
chmod +x scripts/verify_db_extensions.rb
ruby scripts/verify_db_extensions.rb
```

---

## Extension Details

### 1. pgcrypto Extension
**Purpose:** Cryptographic functions and UUID generation

**Use Cases:**
- Generate UUIDs for primary keys: `gen_random_uuid()`
- Password hashing and encryption
- Cryptographic hash functions (MD5, SHA1, SHA256)

**Example Usage:**
```ruby
# In a migration
create_table :users, id: :uuid do |t|
  t.string :email
  t.timestamps
end
```

### 2. pg_trgm Extension
**Purpose:** Trigram-based text search and similarity matching

**Use Cases:**
- Fuzzy text search (typo-tolerant)
- Autocomplete functionality
- Finding similar strings
- Fast LIKE/ILIKE queries with indexes

**Example Usage:**
```ruby
# Find similar names
User.where("name % ?", "Jon")  # Finds "John", "Joan", etc.

# In a migration - create trigram index
add_index :users, :name, using: :gin, opclass: :gin_trgm_ops
```

### 3. hstore Extension
**Purpose:** Key-value pair storage within a single column

**Use Cases:**
- Flexible metadata storage
- User preferences
- Dynamic attributes without schema changes
- Configuration settings

**Example Usage:**
```ruby
# In a migration
add_column :users, :preferences, :hstore, default: {}, null: false
add_index :users, :preferences, using: :gin

# In model
user.preferences = { theme: 'dark', notifications: 'enabled' }
user.save
```

---

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Database Setup Flow                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │  Install PostgreSQL   │
                  │      (v14+)           │
                  └───────────┬───────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │ Create Database User  │
                  │   (aeo_user)          │
                  └───────────┬───────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │  Configure            │
                  │  database.yml         │
                  └───────────┬───────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │  Create Databases     │
                  │  (dev, test, prod)    │
                  └───────────┬───────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │  Generate Migration   │
                  │  for Extensions       │
                  └───────────┬───────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │  Enable Extensions:   │
                  │  • pgcrypto           │
                  │  • pg_trgm            │
                  │  • hstore             │
                  └───────────┬───────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │  Run Migrations       │
                  │  (dev & test)         │
                  └───────────┬───────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │  Verify Extensions    │
                  │  (run test script)    │
                  └───────────┬───────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │  ✅ Database Ready    │
                  │  for Development      │
                  └───────────────────────┘
```

---

## Success Criteria Checklist

- [ ] PostgreSQL 14+ installed and running
- [ ] Database user `aeo_user` created with appropriate privileges
- [ ] `database.yml` configured for all environments
- [ ] `.env` file created with database credentials
- [ ] Development and test databases created successfully
- [ ] Migration for extensions generated and executed
- [ ] pgcrypto extension enabled (verify with `\dx` in psql)
- [ ] pg_trgm extension enabled (verify with `\dx` in psql)
- [ ] hstore extension enabled (verify with `\dx` in psql)
- [ ] Verification script runs without errors
- [ ] UUID generation works (`gen_random_uuid()`)
- [ ] Text similarity search works (pg_trgm)
- [ ] Hstore key-value storage works
- [ ] Database connection successful from Rails console
- [ ] `rails db:migrate:status` shows all migrations up

---

## Troubleshooting

### Issue 1: Permission Denied When Enabling Extensions

**Error:**
```
PG::InsufficientPrivilege: ERROR: permission denied to create extension "pgcrypto"
```

**Solution:**
```bash
# Grant superuser privileges to database user
psql postgres -c "ALTER USER aeo_user WITH SUPERUSER;"

# Or enable extensions as postgres superuser
psql -U postgres aeo_development -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
```

### Issue 2: Extension Not Available

**Error:**
```
ERROR: could not open extension control file: No such file or directory
```

**Solution:**
```bash
# Ubuntu/Debian
sudo apt-get install postgresql-contrib

# macOS (Homebrew)
brew reinstall postgresql@14

# Verify extensions are available
psql -U postgres -c "SELECT * FROM pg_available_extensions WHERE name IN ('pgcrypto', 'pg_trgm', 'hstore');"
```

### Issue 3: Database Connection Refused

**Error:**
```
PG::ConnectionBad: could not connect to server: Connection refused
```

**Solution:**
```bash
# Check if PostgreSQL is running
pg_isready

# Start PostgreSQL
# macOS
brew services start postgresql@14

# Ubuntu/Debian
sudo systemctl start postgresql

# Verify port and host
psql -U aeo_user -h localhost -p 5432 -l
```

### Issue 4: Role Does Not Exist

**Error:**
```
FATAL: role "aeo_user" does not exist
```

**Solution:**
```bash
# Create the user
psql postgres -c "CREATE USER aeo_user WITH PASSWORD 'your_password' CREATEDB SUPERUSER;"
```

### Issue 5: Database Already Exists

**Error:**
```
ActiveRecord::DatabaseAlreadyExists: database "aeo_development" already exists
```

**Solution:**
```bash
# Drop and recreate (WARNING: destroys all data)
rails db:drop db:create db:migrate

# Or just run migrations if database exists
rails db:migrate
```

### Issue 6: Migration Pending

**Error:**
```
ActiveRecord::PendingMigrationError: Migrations are pending
```

**Solution:**
```bash
# Run pending migrations
rails db:migrate

# Check migration status
rails db:migrate:status
```

---

## Future Considerations: TimescaleDB

**Note:** TimescaleDB will be added in a later phase for time-series data optimization.

### What is TimescaleDB?
TimescaleDB is a PostgreSQL extension that adds time-series database capabilities, perfect for:
- Metrics and monitoring data
- Event logs and audit trails
- Performance analytics
- IoT sensor data

### Preparation for TimescaleDB
The current setup is compatible with TimescaleDB. When ready to add it:

1. Install TimescaleDB extension
2. Create a migration to enable it
3. Convert relevant tables to hypertables
4. Configure retention policies

**Migration Preview (Future):**
```ruby
class EnableTimescaledb < ActiveRecord::Migration[7.1]
  def up
    enable_extension 'timescaledb'

    # Convert metrics table to hypertable
    execute <<-SQL
      SELECT create_hypertable('metrics', 'created_at');
    SQL
  end
end
```

---

## Verification Commands

```bash
# Check PostgreSQL version
psql --version

# List all databases
psql -U aeo_user -l

# Connect to development database
psql -U aeo_user aeo_development

# List enabled extensions
\dx

# Check extension versions
SELECT * FROM pg_extension;

# Test database connection from Rails
rails runner "puts ActiveRecord::Base.connection.execute('SELECT version()').first"

# Check migration status
rails db:migrate:status

# Open Rails console and test
rails console
> ActiveRecord::Base.connection.execute("SELECT gen_random_uuid()").first
```

---

## Next Steps

After completing this task, proceed to:

1. **Task 03: Core Models Setup** - Create User, Team, and Organization models using UUID primary keys
2. **Task 04: Authentication Setup** - Implement Devise with database-backed user authentication
3. **Task 05: Database Indexing Strategy** - Add performance indexes using pg_trgm and other optimizations

---

## Additional Resources

- [PostgreSQL Extensions Documentation](https://www.postgresql.org/docs/current/contrib.html)
- [pgcrypto Documentation](https://www.postgresql.org/docs/current/pgcrypto.html)
- [pg_trgm Documentation](https://www.postgresql.org/docs/current/pgtrgm.html)
- [hstore Documentation](https://www.postgresql.org/docs/current/hstore.html)
- [Rails PostgreSQL Guide](https://guides.rubyonrails.org/configuring.html#configuring-a-postgresql-database)
- [TimescaleDB Documentation](https://docs.timescale.com/) (for future reference)

---

## Notes

- Always use environment variables for sensitive credentials
- Never commit `.env` files to version control
- In production, use managed PostgreSQL services (AWS RDS, Google Cloud SQL, etc.)
- Consider connection pooling (PgBouncer) for production deployments
- Regular backups are essential - configure `pg_dump` automation
- Monitor database performance with `pg_stat_statements` extension (can be added later)

---

**Estimated Completion Time:** 2 hours
**Difficulty Level:** Intermediate
**Dependencies:** Task 01 (Rails Application Setup)
**Blocks:** Task 03 (Core Models Setup)

