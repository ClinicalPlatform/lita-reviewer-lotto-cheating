require 'uri'

module Lita
  module Handlers
    class Review < Handler
      route /review\s+(#{ URI.regexp })\b/,
            :lookup_reviewers,
            command: true,
            help: {
              'review GITHUB_PR_URL' => 'Choice 2 reviewer for the github pull request'
            }

      def lookup_reviewers(response)
        pr_url = response.matches[0][0]
        pr_key = "pullrequests:#{Digest::SHA1.hexdigest(pr_url)}"

        return response.reply "#{pr_url} is already assigned to reviewers." \
          if redis.exists(pr_keyB)

        # calculate count of reviewed for each user
        user_points = \
          redis.keys('pullrequests:*')
               .map { |k| redis.smembers(k) }
               .flatten
               .each_with_object({}) do |user, hash|
                 hash[user] = hash.fetch(user, 0) + 1
               end

        members = redis.smembers('reviewers')
        siniors, juniors = members.partition do |user|
          level = redis.hget("users:#{user}", :level).to_i
          level > 1
        end
        reviewers = [siniors, juniors].map do |m|
          # when both users have the same count of reviewd, then determine randomly
          sorted = m.sort_by { |u| [user_points.fetch(u, 0), [-1, 0, 1].sample] }
          sorted.first
        end

        # binding.pry
        # p user_points

        redis.sadd(pr_key, reviewers)
        # a review record expires for 1 month, which is used for review count calculation
        # redis.expire(pr_key, 30 * 24 * 60 * 60)
        redis.expire(pr_key, 300)

        response.reply "#{reviewers.map { |s| "@#{s}" }.join(' and ')} are the reviewers for #{pr_url}!!"
      end

      Lita.register_handler(self)
    end
  end
end
