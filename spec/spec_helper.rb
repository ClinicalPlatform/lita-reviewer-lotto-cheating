require 'lita-reviewer-lotto-cheating'
require 'lita/rspec'
require 'timecop'
require 'vcr'

# A compatibility mode is provided for older plugins upgrading from Lita 3. Since this plugin
# was generated with Lita 4, the compatibility mode should be left disabled.
Lita.version_3_compatibility_mode = false

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock
end

# To enable debug log with testing, uncomment following line.
# Lita.logger.level = Logger::DEBUG

RSpec.configure do |config|
  APP = Lita::Handlers::ReviewerLottoCheating

  config.before(:all, model: true) do
    require 'lita/handlers/reviewer_lotto_cheating/models/pullrequest'
    require 'lita/handlers/reviewer_lotto_cheating/models/user'
    require 'lita/handlers/reviewer_lotto_cheating/model'

    github = APP::Github.new(ENV['GITHUB_ACCESS_TOKEN'])
    APP::Model.list.each do |model_class|
      model_class.init(redis: Lita.redis, github: github) if model_class.respond_to?(:init)
    end
  end

  config.before(:each, model: true) do
    Lita.redis.namespace = 'lita.test'
    keys = Lita.redis.keys("*")
    Lita.redis.del(keys) unless keys.empty?
  end

  # Register lita extensions.
  # see: https://docs.lita.io/plugin-authoring/extensions/#using-extensions
  config.before(:each, lita_handler: true) do
    registry.register_hook(:trigger_route, Lita::Extensions::KeywordArguments)
  end
end

class UserMock < Struct.new(:name, :level, :working_days); end
