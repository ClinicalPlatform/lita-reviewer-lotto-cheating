# frozen_string_literal: true

require_relative '../model'
require_relative '../github'

module Lita::Handlers::ReviewerLottoCheating
  class BaseHandler < Lita::Handler
    def initialize(*args)
      super

      @github = Github.new(config.github_access_token)

      Model.list.each do |model_class|
        model_class.init(redis: redis, github: @github) if model_class.respond_to?(:init)
      end
    end
  end
end
