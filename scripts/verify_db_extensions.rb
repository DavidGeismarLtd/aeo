#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../config/environment"

puts "🔍 Verifying PostgreSQL Extensions...\n\n"

# Test pgcrypto - UUID generation
puts "1. Testing pgcrypto (UUID generation):"
uuid = ActiveRecord::Base.connection.execute("SELECT gen_random_uuid()").first["gen_random_uuid"]
puts "   ✓ Generated UUID: #{uuid}\n\n"

# Test pg_trgm - Similarity search
puts "2. Testing pg_trgm (text similarity):"
similarity = ActiveRecord::Base.connection.execute(
  "SELECT similarity('hello', 'hallo') as score"
).first["score"]
puts "   ✓ Similarity score between 'hello' and 'hallo': #{similarity}\n\n"

# Test hstore - Key-value storage
puts "3. Testing hstore (key-value storage):"
hstore_test = ActiveRecord::Base.connection.execute(
  "SELECT 'key1=>value1, key2=>value2'::hstore as data"
).first["data"]
puts "   ✓ Hstore data: #{hstore_test}\n\n"

# List all enabled extensions
puts "4. Listing all enabled extensions:"
extensions = ActiveRecord::Base.connection.execute(
  "SELECT extname, extversion FROM pg_extension ORDER BY extname"
)
extensions.each do |ext|
  puts "   - #{ext['extname']} (version #{ext['extversion']})"
end
puts "\n"

puts "✅ All PostgreSQL extensions are working correctly!"
