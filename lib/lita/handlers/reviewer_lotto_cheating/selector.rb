# frozen_string_literal: true

require_relative 'models/pullrequest'
require_relative 'models/user'
require_relative 'error'

module Lita::Handlers::ReviewerLottoCheating
  class Selector
    attr_reader :logger

    def initialize(logger:)
      @logger = logger
    end

    def call(duration)
      user_points = Pullrequest.review_counts(duration: duration)
      logger.debug("Current reviewer counts: #{user_points}")

      users = User.list.select(&:working_today?)
      raise Error.new('no user as reviewer candidation') if users.empty?

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
      .reject(&:nil?)
    end
  end
end
