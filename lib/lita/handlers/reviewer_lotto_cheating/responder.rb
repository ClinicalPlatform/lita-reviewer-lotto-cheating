# frozen_string_literal: true

require 'active_support/descendants_tracker'
require 'reviewer_lotto_cheating/common/translatable'

module Lita::Handlers::ReviewerLottoCheating
  class Responder
    extend ActiveSupport::DescendantsTracker
    include Translatable

    class << self
      alias :list :descendants
    end
  end

  # load all responder classes
  require 'reviewer_lotto_cheating/responders/chat_responder'
  require 'reviewer_lotto_cheating/responders/github_comment_responder'
  require 'reviewer_lotto_cheating/responders/github_status_check_responder'
end
