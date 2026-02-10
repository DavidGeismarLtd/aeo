# frozen_string_literal: true

# Enable essential PostgreSQL extensions for the AEO platform
# - pgcrypto: UUID generation and cryptographic functions
# - pg_trgm: Trigram-based text search and similarity matching
# - hstore: Key-value pair storage within a single column
class EnablePostgresqlExtensions < ActiveRecord::Migration[8.1]
  def up
    # Enable pgcrypto for UUID generation
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    # Enable pg_trgm for fuzzy text search and similarity matching
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    # Enable hstore for key-value pair storage
    enable_extension "hstore" unless extension_enabled?("hstore")

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
    disable_extension "hstore" if extension_enabled?("hstore")
    disable_extension "pg_trgm" if extension_enabled?("pg_trgm")
    disable_extension "pgcrypto" if extension_enabled?("pgcrypto")
  end
end
