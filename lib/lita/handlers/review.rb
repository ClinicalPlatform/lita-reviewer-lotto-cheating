require 'uri'
require 'octokit'

module Lita
  module Handlers
    class Review < Handler
      config :github_access_token

      route /review\s+(#{ URI.regexp })\b/,
            :lookup_reviewers,
            command: true,
            help: {
              'review GITHUB_PR_URL' => t('help.description')
            }

      def parse_uri(uri)
        pr_uri =
          URI.parse(uri).tap do |u|
            raise Error.new(t('error.invalid_uri', uri: u)) \
              unless u.scheme =~ /^https?$/ \
                and  u.host == 'github.com'
          end

        _, repo_path, pr_id = pr_uri.path.match(%r|^((?:/[^/]+){2})/pull/(\d+).*$|).to_a
        repo_uri            = pr_uri.clone().tap { |u| u.path = repo_path }
        raise Error.new(t('error.invalid_uri', uri: uri)) \
          unless repo_path and pr_id

        [repo_uri, pr_uri, pr_id]
      end

      def lookup_reviewers(response)
        @response = response

        begin
          repo_uri, pr_uri, pr_id = parse_uri(response.matches[0][0])
        rescue Error, URI::InvalidURIError => e
          return error(e.message)
        end

        @gh_client = Octokit::Client.new(access_token: config.github_access_token)
        @repo      = Octokit::Repository.from_url("#{repo_uri}")
        begin
          @pr = @gh_client.pull_request(@repo, pr_id)
        rescue => e
          return error(e.message)
        end

        pr_key = "pullrequests:#{pr_uri.path}"
        return response.reply t('reply.already_assigned', uri: pr_uri) \
          if redis.exists(pr_key)

        # calculate count of reviewed for each user
        user_points = \
          redis.keys('pullrequests:*')
               .map { |k| redis.smembers(k) }
               .flatten
               .each_with_object({}) do |user, hash|
                 hash[user] = hash.fetch(user, 0) + 1
               end

        members = redis.smembers('users')
        siniors, juniors = members.partition do |user|
          level = redis.hget("users:#{user}", :level).to_i
          level > 1
        end
        reviewers = [siniors, juniors].map do |m|
          # when both users have the same count of reviewd, then determine randomly
          sorted = m.sort_by { |u| [user_points.fetch(u, 0), [-1, 0, 1].sample] }
          sorted.first
        end

        p user_points

        # save pullrequest reviewer record to redis
        redis.sadd(pr_key, reviewers)
        # a review record expires for 1 month, which is used for review count calculation
        # redis.expire(pr_key, 30 * 24 * 60 * 60)
        redis.expire(pr_key, 300)

        write_pr_comment(pr_id, reviewers)

        response.reply t(
          'reply.success.chat',
          reviewers: reviewers.map { |s| "@#{s}" }.join(' and '),
          uri: pr_uri,
        )
      end

      private

      # write comment to tell assignment of the reviewers to github pullrequest page
      def write_pr_comment(pr_id, reviewers)
        @gh_client.add_comment(
          @repo,
          pr_id,
          t('reply.success.comment', reviewers: reviewers.join(' and '))
        )
      end

      def error(text)
        @response&.reply("Error: #{text}")
      end

      Lita.register_handler(self)
    end

    class Error < ::StandardError; end
  end
end
