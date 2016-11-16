require 'reviewer_lotto_cheating/github'

module Lita::Handlers::ReviewerLottoCheating
  class Handler < Lita::Handler
    def initialize(*args)
      super

      @github = Github.new(config.github_access_token)

      Model.list.each do |model_class|
        model_class.init(redis: redis, github: @github) if model_class.respond_to?(:init)
      end
    end
  end

  # load all handler classes
  require 'reviewer_lotto_cheating/handlers/reviewer_handler'
  require 'reviewer_lotto_cheating/handlers/user_handler'
end
