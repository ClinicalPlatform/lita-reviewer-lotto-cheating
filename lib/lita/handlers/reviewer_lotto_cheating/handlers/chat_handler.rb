# frozen_string_literal: true

require 'pry'
require 'uri'
require_relative '../error'
require_relative '../models/pullrequest'
require_relative '../models/user'
require_relative '../responder'
require_relative '../selector'
require_relative 'base_handler'

module Lita::Handlers::ReviewerLottoCheating
  class ChatHandler < BaseHandler
    namespace 'reviewer_lotto_cheating'

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
        'reviewer GITHUB_PR_URL' => t('help.reviewer')
      }

    def assign_reviewers_to_all(_payload)
      return logger.info(
        "'config.handlers.reviewer.repositories' is not set, skip."
      ) unless config.repositories

      begin
        prs = Pullrequest.list(config.repositories)
      rescue Octokit::Error => e
        return on_error(e.message)
      end

      logger.debug("Found pullrequests: #{prs.map(&:path)}")

      prs.each do |pr| assign_reviewers(pr) end
    end

    def assign_reviewers_from_chat(response)
      assign_reviewers_from_url(response.matches[0][0])
    end

    def assign_reviewers_from_url(url)
      begin
        pr = Pullrequest.from_url(url)
      rescue Error, Octokit::Error => e
        return on_error(e.message)
      end

      assign_reviewers(pr)
    end

    private

    def assign_reviewers(pr)
      return logger.info("#{pr.html_url} is already assigned") if pr.assigned?

      reviewers =
        begin
          Selector.call(config.reviewer_count_duration)
        rescue Error => e
          return on_error(e.message)
        end
      logger.debug("Select #{User.to_text(reviewers)} on #{pr.path}")

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
        Responder.list.map do |responder_class|
          responder_class.new(robot: robot, github: @github, config: config)
        end
    end

    def logger
      Lita.logger
    end

    Lita.register_handler(self)
  end
end
