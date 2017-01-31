# frozen_string_literal: true

require 'lita/handlers/reviewer_lotto_cheating/responder'

module Lita::Handlers::ReviewerLottoCheating
  class GithubReviewRequestResponder < Responder
    def initialize(github:, **kwargs)
      @github = github
    end

    def on_assigned(pr, reviewers)
      @github.request_pull_request_review(pr.repo, pr.number, reviewers.map(&:name))
      true
    end
  end
end
