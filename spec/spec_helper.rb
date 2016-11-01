require 'lita-reviewer'
require 'lita/rspec'
require 'vcr'

# A compatibility mode is provided for older plugins upgrading from Lita 3. Since this plugin
# was generated with Lita 4, the compatibility mode should be left disabled.
Lita.version_3_compatibility_mode = false

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock
end

RSpec.configure do |config|
  config.before(:each, model: true) do
    stub_const("Lita::REDIS_NAMESPACE", "lita.test")
    keys = Lita.redis.keys("*")
    Lita.redis.del(keys) unless keys.empty?
  end
end
