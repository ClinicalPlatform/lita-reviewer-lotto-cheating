# frozen_string_literal: true

require 'uri'
require 'reviewer_lotto_cheating/error'
require 'reviewer_lotto_cheating/models/pullrequest'
require 'reviewer_lotto_cheating/models/user'
require 'reviewer_lotto_cheating/responder'
require 'reviewer_lotto_cheating/selector'
require 'reviewer_lotto_cheating/handlers/base_handler'

module Lita::Handlers::ReviewerLottoCheating
  class ReviewerHandler < BaseHandler
    namespace 'reviewer_lotto_cheating'

    config :github_access_token, type: String, required: true
    # repositories to review
    config :repositories, type: [Object], required: true
    # duration time (second) from now, which is used to calculate review count
    # for specific user when selecting reviewers
    config :reviewer_count_duration, type: Numeric, default: 30 * 24 * 60 * 60
    # room(channel) or user to which this handler sends messages
    config :chat_target, type: Hash, default: { room: '#general' }

    on :connected, :validate_repositories

    route /reviewer\s+all\b/,
      :assign_reviewers_to_all_from_chat,
      command: true,
      help: {
        'reviewer GITHUB_PR_URL' => t('help.reviewer')
      }
    route /reviewer\s+(#{ URI.regexp })\b/,
      :assign_reviewers_from_chat,
      command: true,
      help: {
        'reviewer GITHUB_PR_URL' => t('help.reviewer')
      }

    # ex: http://localhost:8080/assign_reviewer/all
    http.get '/assign_reviewer/all', :assign_reviewers_to_all_from_http

    # ex: http://localhost:8080/assign_reviewer/foobar/test1/pull/3
    http.get '/assign_reviewer/*path', :assign_reviewers_from_http

    def validate_repositories(_payload)
      unless config.repositories.is_a?(Array) and config.repositories.present?
        logger.fatal("'config.handlers.reviewer_lotto_cheating.repositories' must be Array and not be empty, abort.")
        abort
      end
    end

    def assign_reviewers_to_all_from_http(_request, _response)
      assign_reviewers_to_all
    end

    def assign_reviewers_from_http(request, _response)
      path = request.env['router.params'][:path].join('/')
      assign_reviewers_from_path(path)
    end

    def assign_reviewers_to_all_from_chat(_response)
      assign_reviewers_to_all
    end

    def assign_reviewers_from_chat(response)
      assign_reviewers_from_url(response.matches[0][0])
    end

    def assign_reviewers_to_all
      begin
        prs = Pullrequest.list(config.repositories)
      rescue Octokit::Error => e
        return on_error(e.message)
      end

      logger.debug("Found pullrequests: #{prs.map(&:path)}")

      prs.each do |pr| assign_reviewers(pr) end
    end

    def assign_reviewers_from_path(path)
      url = "https://github.com/#{path}"
      assign_reviewers_from_url(url)
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
      return on_exit(t('message.already_assigned', url: pr.html_url)) \
        if pr.assigned?

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

    def on_exit(text)
      logger.info("#{text}; exit.")

      responders.each do |responder|
        responder.on_exit(text) if responder.respond_to?(:on_exit)
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
