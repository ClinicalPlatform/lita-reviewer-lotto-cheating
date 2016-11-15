# frozen_string_literal: true

require 'reviewer_lotto_cheating/models/pullrequest'
require 'reviewer_lotto_cheating/models/user'
require 'reviewer_lotto_cheating/error'

module Lita::Handlers::ReviewerLottoCheating
  class Selector
    class << self
      def call(duration)
        users = User.list.select(&:working_today?)
        raise Error.new('no user as reviewer candidation') if users.empty?

        user_points = Pullrequest.calc_review_counts(duration: duration)
        Lita.logger.debug("Current reviewer counts: #{user_points}")

        select(users, user_points)
      end

      private

      def select(users, user_points)
        siniors, juniors = users.partition { |user| user.level > 1 }

        [siniors, juniors].map do |group|
          # when both users have the same reviewed count, then select randomly
          sorted = group.sort_by do |u|
            [user_points.fetch(u.name, 0), [-1, 0, 1].sample]
          end
          sorted.first
        end
        .compact
      end
    end
  end
end
