# frozen_string_literal: true

require 'reviewer_lotto_cheating/responder'

module Lita::Handlers::ReviewerLottoCheating
  class GithubCommentResponder < Responder
    def initialize(github:, **kwargs)
      @github = github
    end

    def on_assigned(pr, reviewers)
      text = t('message.assigned_reviewers.comment',
               reviewers: reviewers.map(&:screen_name).join(', '))
      @github.add_comment(pr.repo, pr.number, text)
      true
    end
  end
end
