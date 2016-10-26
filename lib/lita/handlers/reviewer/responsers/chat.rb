require 'lita'
require_relative 'base'

module Lita::Handlers::Reviewer::Responsers
  class Chat < Base
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
  end
end
