require 'lita-reviewer-lotto-cheating'
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
  NS = Lita::Handlers::ReviewerLottoCheating

  config.before(:all, model: true) do
    require 'lita/handlers/reviewer_lotto_cheating/models/pullrequest'
    require 'lita/handlers/reviewer_lotto_cheating/models/user'
    require 'lita/handlers/reviewer_lotto_cheating/model'

    lita_config = Lita.config.handlers.reviewer_lotto_cheating
    github      = NS::Github.new(access_token: lita_config.github_access_token)
    NS::Model.list.each do |model_class|
      model_class.init(redis: Lita.redis, github: github) if model_class.respond_to?(:init)
    end
  end

  config.before(:each, model: true) do
    Lita.redis.namespace = 'lita.test'
    keys = Lita.redis.keys("*")
    Lita.redis.del(keys) unless keys.empty?
  end
end
