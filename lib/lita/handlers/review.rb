require 'pry'

require 'octokit'
require 'uri'

module Lita
  module Handlers
    class Review < Handler
      config :github_access_token
      # expiration time (second) of a redis entry which records pullrequest reviewers,
      # which is used to calculate review count for specific user when selecting reviewers
      config :pullrequest_log_expiration

      route /review\s+(#{ URI.regexp })\b/,
            :lookup_reviewers,
            command: true,
            help: {
              'review GITHUB_PR_URL' => t('help.description')
            }

      def lookup_reviewers(response)
        @response = response
        uri = @response.matches[0][0]

        begin
          prepare_repository_client(uri)
        rescue Error, Octokit::Error, URI::InvalidURIError => e
          return error(e.message)
        end

        # do not select reviewers when it has already done for the PR.
        pr_key = "pullrequests:#{URI.parse(@pr.html_url).path}"
        return response.reply t('reply.already_assigned', uri: @pr.html_url) \
          if redis.exists(pr_key)

        reviewers = select_reviewers

        begin
          write_pr_comment(reviewers)
        rescue Octokit::Error => e
          return error(t('error.comment_failure', text: e.message))
        end

        response.reply t(
          'reply.selected_reviewers.chat',
          reviewers: reviewers.map { |s| "@#{s}" }.join(' and '),
          uri: @pr.html_url,
        )

        save_reviwers(
          pr_key,
          reviewers,
          expiration: config.pullrequest_log_expiration || 30 * 24 * 60 * 60  # default 1 month
        )
      end

      private

      def prepare_repository_client(uri)
        repo_uri, pr_uri, pr_number = parse_uri(uri)
        @gh_client = Octokit::Client.new(access_token: config.github_access_token)
        @repo      = Octokit::Repository.from_url("#{repo_uri}")
        @pr        = @gh_client.pull_request(@repo, pr_number)
      end

      def parse_uri(uri)
        pr_uri =
          URI.parse(uri).tap do |u|
            raise Error.new(t('error.invalid_uri', uri: u)) \
              unless u.scheme =~ /^https?$/ \
                and  u.host == 'github.com'
          end

        _, repo_path, pr_number = pr_uri.path.match(%r|^((?:/[^/]+){2})/pull/(\d+).*$|).to_a
        repo_uri                = pr_uri.clone().tap { |u| u.path = repo_path }
        raise Error.new(t('error.invalid_uri', uri: uri)) \
          unless repo_path and pr_number

        [repo_uri, pr_uri, pr_number]
      end

      def select_reviewers
        # calculate count of reviewed for each user
        user_points = \
          redis.keys('pullrequests:*')
               .map { |k| redis.smembers(k) }
               .flatten
               .each_with_object({}) do |user, hash|
                 hash[user] = hash.fetch(user, 0) + 1
               end
        # p user_points

        members = redis.smembers('users')
        siniors, juniors = members.partition do |user|
          level = redis.hget("users:#{user}", :level).to_i
          level > 1
        end
        reviewers = [siniors, juniors].map do |m|
          # when both users have the same reviewed count, then select randomly
          sorted = m.sort_by { |u| [user_points.fetch(u, 0), [-1, 0, 1].sample] }
          sorted.first
        end
      end

      # write comment to tell assignment of the reviewers to github pullrequest page
      def write_pr_comment(reviewers)
        @gh_client.add_comment(
          @repo,
          @pr.number,
          t('reply.selected_reviewers.comment', reviewers: reviewers.join(' and '))
        )
      end

      def save_reviwers(pr_key, reviewers, expiration:)
        redis.sadd(pr_key, reviewers)
        # a review record expires for `expiration`, which is used for review count calculation
        # redis.expire(pr_key, 30 * 24 * 60 * 60)
        redis.expire(pr_key, expiration)
      end

      def error(text)
        @response&.reply("Error: #{text}")
      end

      Lita.register_handler(self)

      class Error < ::StandardError; end
    end
  end
end
