require_relative 'github'
require_relative 'registory'

module Lita::Handlers::Reviewer
  class Handler < Lita::Handler
    def initialize(*args)
      super

      @github = Github.new(config.github_access_token)

      Registory.models.each do |klass|
        klass.init(redis: redis, github: @github) if klass.respond_to?(:init)
      end
    end
  end
end
