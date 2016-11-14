# frozen_string_literal: true

module Lita::Handlers::ReviewerLottoCheating
  class Responder
    class << self
      def list
        @responders ||= []
      end
    end

    require 'reviewer_lotto_cheating/responders/chat_responder'
    require 'reviewer_lotto_cheating/responders/github_comment_responder'
    require 'reviewer_lotto_cheating/responders/github_status_check_responder'
  end
end
