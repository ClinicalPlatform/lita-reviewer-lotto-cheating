# frozen_string_literal: true

require 'lita/handlers/reviewer_lotto_cheating/models/pullrequest'
require 'lita/handlers/reviewer_lotto_cheating/models/user'
require 'lita/handlers/reviewer_lotto_cheating/error'

module Lita::Handlers::ReviewerLottoCheating
  class Selector
    class << self
      def call(users:, duration:, random_weight: nil)
        raise Error.new('no user as reviewer candidation') if users.empty?

        user_points = Pullrequest.calc_review_counts(duration: duration)
        Lita.logger.debug("Current reviewer counts: #{user_points}")

        select(users, user_points, random_weight: random_weight)
      end

      private

      def select(users, reviewed_counts, random_weight: nil)
        siniors, juniors = users.partition { |user| user.level > 1 }
        hasEmptyGroup = [siniors, juniors].any?(&:empty?)

        [siniors, juniors]
          .reject(&:empty?)
          .map do |group|
            sorted = sort_users_by_point_and_lotto(group, reviewed_counts, random_weight: random_weight)
            sorted.take(hasEmptyGroup ? 2 : 1)
          end
          .flatten
      end

      def sort_users_by_point_and_lotto(users, reviewed_counts, random_weight: nil)
        user_points = users.map do |u|
          num_working_days = u.working_days.size.nonzero? || 1
          # reviewed point is multiplied by 100 and rounded off
          point = (reviewed_counts.fetch(u.name, 0).to_f / num_working_days * 100).round
          [u, point]
        end.to_h

        random_weight = random_weight.try! { self % 101 } || 20    # default 20
        review_weight = 100 - random_weight
        Lita.logger.debug(
          "Sort reviewers [#{users.map(&:name).join(', ')}] by " \
          "reviewed count : random = #{review_weight} : #{random_weight}"
        )

        max_point = user_points.max_by { |t| t[1] }&.at(1)&.nonzero? || 100

        users.sort_by do |u|
          review_point = user_points.fetch(u, 0) * review_weight
          random_point = (rand(max_point) + 1)   * random_weight
          point        = review_point + random_point
          Lita.logger.debug(
            "[#{u.name} - lv.#{u.level}] review: #{review_point}, " \
            "random: #{random_point}: total: #{point}"
          )
          point
        end
      end
    end
  end
end
