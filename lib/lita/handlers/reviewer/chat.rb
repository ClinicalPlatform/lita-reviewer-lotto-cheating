# frozen_string_literal: true

require 'pry'
require 'octokit'
require 'uri'
require_relative 'error'
require_relative 'github'
require_relative 'pullrequest'
require_relative 'registory'
require_relative 'selector'
require_relative 'user'
require_relative 'responders/chat'
require_relative 'responders/github_comment'
require_relative 'responders/github_status_check'


module Lita::Handlers::Reviewer
  class Chat < Lita::Handler
    namespace 'reviewer'

    config :github_access_token, type: String, required: true
    # repositories to review
    config :repositories, type: [Object], required: true
    # duration time (second) from now, which is used to calculate review count
    # for specific user when selecting reviewers
    config :reviewer_count_duration, type: Numeric, default: 30 * 24 * 60 * 60
    # room(channel) or user to which this handler sends messages
    config :chat_target, type: Hash, default: { room: '#general' }

    on :connected, :assign_reviewers_to_all

    route /reviewer\s+(#{ URI.regexp })\b/,
      :assign_reviewers_from_chat,
      command: true,
      help: {
        'reviewer GITHUB_PR_URL' => t('help.description')
      }

    def initialize(*args)
      super

      @github = Github.new(config.github_access_token)

      Registory.models.each do |klass|
        klass.init(redis: redis, github: @github) if klass.respond_to?(:init)
      end
    end

    def assign_reviewers_to_all(_payload)
      return logger.info(
        "'config.handlers.reviewer.repositories' is not set, skip."
      ) unless config.repositories

      prs = Pullrequest.list(config.repositories)
      logger.debug("Found pullrequests: #{prs.map(&:path)}")

      prs.each do |pr|
        reviewers = assign_reviewers(pr)
      end
    end

    def assign_reviewers_from_chat(response)
      assign_reviewers_from_url(response.matches[0][0])
    end

    def assign_reviewers_from_url(url)
      pr = Pullrequest.from_url(url)
      assign_reviewers(pr)
    end

    private

    def assign_reviewers(pr)
      return logger.info("#{pr.html_url} is already assigned") if pr.assigned?

      reviewers = Selector.new(logger: logger).call(config.reviewer_count_duration)
      logger.debug("Select #{User.to_text(reviewers)} on #{pr.path}")

      text = t('message.assigned_reviewers.comment',
               reviewers: User.to_text(reviewers))

      on_assigned(pr, reviewers)

      pr.save(reviewers)
      logger.info("Assigned #{User.to_text(reviewers)} as reviewers for #{pr.html_url}")
    end

    def on_assigned(pr, reviewers)
      responders.each do |responder|
        next unless responder.respond_to?(:on_assigned)
        begin
          responder.on_assigned(pr, reviewers)
        rescue Error, Octokit::Error => e
          on_error(e.message)
        end
      end
    end

    def on_error(text)
      logger.error(text)

      responders.each do |responder|
        responder.on_error(text) if responder.respond_to?(:on_error)
      end
    end

    def responders
      @responders ||=
        Registory.responders.map do |klass|
          klass.new(robot: robot, github: @github, config: config)
        end
    end

    def logger
      Lita.logger
    end

    Lita.register_handler(self)
  end
end
