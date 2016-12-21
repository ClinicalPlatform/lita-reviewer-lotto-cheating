# frozen_string_literal: true

require 'lita'
require 'reviewer_lotto_cheating/responder'

module Lita::Handlers::ReviewerLottoCheating
  class ChatResponder < Responder
    def initialize(robot:, config:, **kwargs)
      @robot  = robot
      @config = config
      @target = Lita::Source.new(@config.chat_target)
    end

    def on_assigned(pr, reviewers)
      text = t('message.assigned_reviewers.comment',
               reviewers: reviewers.map(&:screen_name).join(', '))

      @robot.send_message(@target, t(
        'message.assigned_reviewers.chat',
        reviewers: reviewers.map(&:screen_name).join(', '),
        url: pr.html_url,
      ))
      true
    end

    def on_error(message)
      text = "Error: #{message}"
      @robot.send_message(@target, text)
    end

    def on_exit(message)
      @robot.send_message(@target, message)
    end
  end
end
