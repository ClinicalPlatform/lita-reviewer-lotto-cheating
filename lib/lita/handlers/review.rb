# frozen_string_literal: true

require 'pry'

require 'octokit'
require 'uri'

module Lita
  module Handlers
    class Review < Handler
      REDIS_PULLREQUESTS_KEY         = 'pullrequests'
      REDIS_ORDERED_PULLREQUESTS_KEY = 'pullrequests_ordered'
      REDIS_USERS_KEY                = 'users'

      config :github_access_token
      # repositories to review
      config :repositories
      # duration time (second) from now, which is used to calculate review count
      # for specific user when selecting reviewers
      config :reviewer_count_duration
      # labels that is set to pullrequests for review
      config :pr_labels
      # default room(channel) or user to which this handler sends messages
      config :default_chat_target

      on :connected, :assign_reviewers_to_all

      route /reviewer\s+(#{ URI.regexp })\b/,
            :assign_reviewers_from_chat,
            command: true,
            help: {
              'reviewer GITHUB_PR_URL' => t('help.description')
            }

      def initialize(*args)
        super
        @gh_client = Octokit::Client.new(
          access_token: config.github_access_token
        )
      end

      def assign_reviewers_to_all(_payload)
        return logger.info(
          %('config.handlers.review.repositories' is not set. exit.)
        ) unless config.repositories

        prs = pull_requests(config.repositories)
        logger.debug("Found pullrequests: #{prs.map { |pr| URI.parse(pr.html_url).path }}")

        prs.each do |pr|
          assign_reviewers(pr)
        end
      end

      def assign_reviewers_from_chat(response)
        begin
          assign_reviewers_from_uri(response.matches[0][0])
        rescue Error, Octokit::Error => e
          send_error(e.message, target: response)
        end
      end

      def assign_reviewers_from_uri(uri)
        repo_uri, pr_uri, pr_number = parse_uri(uri)
        repo = Octokit::Repository.from_url("#{repo_uri}")
        pr   = @gh_client.pull_request(repo, pr_number)

        assign_reviewers(pr)
      end

      private

      def assign_reviewers(pr)
        key = pr_key(pr)
        return logger.info("#{pr.html_url} is already assigned") \
          if redis.sismember(REDIS_PULLREQUESTS_KEY, pr.id)

        reviewers = select_reviewers(*config.reviewer_count_duration)
        logger.debug("Select #{reviewers} on #{pr.html_url}")

        begin
          write_pr_comment(pr, reviewers)
        rescue Octokit::Error => e
          return logger.error("Failed to write comment to the pullrequest page: #{e.message}")
        end

        target = Source.new(room: '#general')
        robot.send_message(target, t(
          'message.assigned_reviewers.chat',
          reviewers: reviewers.map { |s| "@#{s}" }.join(', '),
          uri: pr.html_url,
        ) )

        save_to_redis(key: key, pr_id: pr.id, reviewers: reviewers)

        logger.info("Assigned #{reviewers.join(', ')} as reviewers for #{pr.html_url}")
      end

      def pull_requests(repositories)
        repositories.map do |repository|
          repo_name =
            case repository
            when String then repository
            when Hash   then repository[:name]
            end
          options =
            case repository
            when Hash   then { labels: repository[:labels].join(',') }
            else {}
            end

          repo   = Octokit::Repository.new(repo_name)
          pulls  = @gh_client.pulls(repo_name)
          issues = @gh_client.issues(repo_name, options).select { |i| i.pull_request }

          issues.map do |issue|
            pulls.find { |pull| pull.number == issue.number }
          end.reject(&:nil?)
        end.flatten
      end

      def parse_uri(uri)
        pr_uri =
          URI.parse(uri).tap do |u|
            raise Error.new(t('error.invalid_uri', uri: u)) \
              unless u.scheme =~ /^https?$/ and u.host == 'github.com'
          end

        _, repo_path, pr_number = pr_uri.path.match(%r|^((?:/[^/]+){2})/pull/(\d+).*$|).to_a
        repo_uri                = pr_uri.clone().tap { |u| u.path = repo_path }
        raise Error.new(t('error.invalid_uri', uri: uri)) \
          unless repo_path and pr_number

        [repo_uri, pr_uri, pr_number]
      end

      def select_reviewers_by_working_days(members)
        members.select do |member|
          working_days = redis.smembers("#{REDIS_USERS_KEY}:#{member}:working_days")
                              .map(&:to_i)
          working_days.include?(DateTime.now.cwday)
        end
      end

      def select_reviewers(duration = 30 * 24 * 60 * 60)
        # calculate count of reviewed for each user
        now   = Time.now.to_i
        start = now - duration
        user_points = \
          redis.zrangebyscore(REDIS_ORDERED_PULLREQUESTS_KEY, start, now)
               .map { |k| redis.smembers(k) }
               .flatten
               .each_with_object({}) do |user, hash|
                 hash[user] = hash.fetch(user, 0) + 1
               end
        logger.debug("Current reviewer counts: #{user_points}")

        members = select_reviewers_by_working_days(
          redis.smembers(REDIS_USERS_KEY)
        )

        siniors, juniors = members.partition do |user|
          level = redis.get("#{REDIS_USERS_KEY}:#{user}:level").to_i
          level > 1
        end
        reviewers = [siniors, juniors].map do |m|
          # when both users have the same reviewed count, then select randomly
          sorted = m.sort_by { |u| [user_points.fetch(u, 0), [-1, 0, 1].sample] }
          sorted.first
        end
      end

      # write comment to tell assignment of the reviewers to github pullrequest page
      def write_pr_comment(pr, reviewers)
        reviewers_text = reviewers.join(', ')
        text = t('message.assigned_reviewers.comment',
                 reviewers: reviewers_text)
        repo = pr.head.repo.full_name

        @gh_client.add_comment(repo, pr.number, text)
        logger.debug("Wrote a comment on #{pr.html_url}")

        # display in status check
        @gh_client.create_status(
          repo, pr.head.sha, :pending,
          context: t('application_name'),
          description: text
        )
        logger.debug("Set status on #{pr.html_url}")
      end

      def save_to_redis(key:, pr_id:, reviewers:)
        # To detect whether or not it was reviewd in the future
        redis.sadd(REDIS_PULLREQUESTS_KEY, pr_id)
        # a review record which is used for review count calculation
        redis.zadd(REDIS_ORDERED_PULLREQUESTS_KEY, Time.now.to_i, key)
        # log to assing reviewers
        redis.sadd(key, reviewers)
      end

      def pr_key(pr)
        "#{REDIS_PULLREQUESTS_KEY}:#{URI.parse(pr.html_url).path}"
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
