# frozen_string_literal: true

require 'forwardable'
require 'reviewer_lotto_cheating/error'
require 'reviewer_lotto_cheating/model'

module Lita::Handlers::ReviewerLottoCheating
  class Pullrequest < Model
    extend Forwardable

    attr_reader :redis
    def_delegators :@pr, :html_url, :number, :id

    PULLREQUESTS_KEY         = 'pullrequests'
    ORDERED_PULLREQUESTS_KEY = 'pullrequests_ordered'

    def initialize(pr, redis: nil)
      @pr    = pr
      @redis = redis || self.class.redis
    end

    def assigned?
      redis.sismember(PULLREQUESTS_KEY, @pr.id)
    end

    def key
      "#{PULLREQUESTS_KEY}:#{path}"
    end

    def save(reviewers)
      # save for detection of whether or not it was reviewd
      redis.sadd(PULLREQUESTS_KEY, @pr.id)
      # save for review count calculation
      redis.zadd(ORDERED_PULLREQUESTS_KEY, Time.now.to_i, key)
      # log of reviewers assignment
      redis.sadd(key, reviewers.map(&:name))
    end

    def latest_commit
      @pr.head.sha
    end

    def repo
      @pr.head.repo.full_name
    end

    def path
      URI.parse(@pr.html_url).path
    end

    class << self
      attr_accessor :redis, :github

      def init(redis:, github:)
        @redis  = redis
        @github = github
      end

      def from_url(url)
        repo, pr_number = parse_url(url)
        pr = github.pull_request(repo, pr_number)
        new(pr)
      end

      # @param repositories [Hash or String]
      #   repositories from which we get pullrequests
      #
      #   example:
      #
      #   config.handlers.reviewer.repositories = [
      #     # get whole open pullrequests from this repo
      #     'foo/repo2'
      #     # get only open pullrequests specified by labels from this repo
      #     {
      #       name: 'foo/repo1',
      #       labels: ['require review']
      #     },
      #   ]
      def list(repositories)
        github.pullrequests(repositories).map { |pr| new(pr) }
      end

      # calculate count of reviewed for each user
      def calc_review_counts(duration:)
        now   = Time.now.to_i
        start = now - duration

        redis.zrangebyscore(ORDERED_PULLREQUESTS_KEY, start, now)
          .map { |k| redis.smembers(k) }
          .flatten
          .each_with_object({}) do |user, hash|
            hash[user] = hash.fetch(user, 0) + 1
          end
      end

      private

      def parse_url(s)
        url = URI.parse(s).tap do |u|
                raise Error.new("'#{u}' is not github pullrequest URL.") \
                  unless u.scheme =~ /\Ahttps?\z/ and u.host == 'github.com'
              end

        _, repo_name, pr_number = url.path.match(%r|^/([^/]+/[^/]+)/pull/(\d+).*\z|).to_a
        raise Error.new("'#{s}' is not github pullrequest URL.") \
          unless repo_name and pr_number

        [repo_name, pr_number]
      end
    end
  end
end
