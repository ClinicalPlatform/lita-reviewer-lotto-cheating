# frozen_string_literal: true

require 'lita/handlers/reviewer_lotto_cheating/models/pullrequest'
require 'lita/handlers/reviewer_lotto_cheating/models/user'
require 'lita/handlers/reviewer_lotto_cheating/error'

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

      def select(users, reviewed_counts)
        siniors, juniors = users.partition { |user| user.level > 1 }

        [siniors, juniors].map do |group|
          user_points = group.map do |u|
            num_working_days = u.working_days.size.nonzero? || 1
            # reviewed point is multiplied by 100 and rounded off
            point = (reviewed_counts.fetch(u.name, 0).to_f / num_working_days * 100).round
            [u, point]
          end.to_h

          max_point = user_points.max_by {|t| t[1] }&.at(1)&.nonzero? || 100
          sorted = group.sort_by do |u|
            # final point consists of the ratio of 'reviewed point' to 'random point' are 8 : 2
            reviewed_point = user_points.fetch(u, 0) * 8
            random_point   = (rand(max_point) + 1) * 2
            point          = reviewed_point + random_point
            Lita.logger.debug(
              "[#{u.name} - lv.#{u.level}] review: #{reviewed_point}, " \
              "random: #{random_point}: total: #{point}"
            )
            point
          end
          sorted.first
        end
        .compact
      end
    end
  end
end
