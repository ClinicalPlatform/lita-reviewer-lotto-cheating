# frozen_string_literal: true

require 'pry'

require 'octokit'
require 'uri'

require 'lita/handlers/reviewer/github'
require 'lita/handlers/reviewer/pullrequest'
require 'lita/handlers/reviewer/user'

module Lita
  module Handlers
    class Reviewer < Handler
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

      attr_reader :github

      def initialize(*args)
        super

        @github = Github.new(config.github_access_token)

        [Pullrequest, User].each do |cls|
          cls.prepare(redis, github) if cls.respond_to?(:prepare)
        end
      end

      def assign_reviewers_to_all(_payload)
        return logger.info(
          %('config.handlers.reviewer.repositories' is not set, exit.)
        ) unless config.repositories

        prs = Pullrequest.list(config.repositories)

        logger.debug("Found pullrequests: #{prs.map(&:path)}")

        prs.each do |pr|
          assign_reviewers(pr)
        end
      end

      def assign_reviewers_from_chat(response)
        begin
          assign_reviewers_from_url(response.matches[0][0])
        rescue Error, Octokit::Error => e
          send_error(e.message, target: response)
        end
      end

      def assign_reviewers_from_url(url)
        pr = Pullrequest.from_url(url)
        assign_reviewers(pr)
      end

      private

      def assign_reviewers(pr)
        return logger.info("#{pr.html_url} is already assigned") if pr.assigned?

        reviewers = select_reviewers(config.reviewer_count_duration)
        logger.debug("Select #{User.to_text(reviewers)} on #{pr.path}")

        text = t('message.assigned_reviewers.comment',
                 reviewers: User.to_text(reviewers))
        begin
          github.write_comment(pr, text)
        rescue Octokit::Error => e
          return logger.error("Failed to write comment to the pullrequest page: #{e.message}")
        end
        begin
          github.create_status(pr, t('application_name'), text)
        rescue Octokit::Error => e
          return logger.error("Failed to set status to the pullrequest page: #{e.message}")
        end

        target = Source.new(config.chat_target)
        robot.send_message(target, t(
          'message.assigned_reviewers.chat',
          reviewers: User.to_text(reviewers),
          url: pr.html_url,
        ))

        pr.save(reviewers)

        logger.info("Assigned #{User.to_text(reviewers)} as reviewers for #{pr.html_url}")
      end

      def select_reviewers(duration)
        user_points = Pullrequest.review_counts(duration: duration)
        logger.debug("Current reviewer counts: #{user_points}")

        users = User.list.select(&:working_today?)

        siniors, juniors = users.partition { |user| user.level > 1 }
        [siniors, juniors].map do |group|
          # when both users have the same reviewed count, then select randomly
          sorted = group.sort_by do |u|
            [user_points.fetch(u.name, 0), [-1, 0, 1].sample]
          end
          sorted.first
        end
      end

      def send_error(text, target:)
        text = "Error: #{text}"
        case target
        when Lita::Source
          robot.send_message(target, text)
        when Lita::Response
          target.reply(text)
        end
      end

      def logger
        Lita.logger
      end

      Lita.register_handler(self)

      class Error < ::StandardError; end
    end
  end
end
