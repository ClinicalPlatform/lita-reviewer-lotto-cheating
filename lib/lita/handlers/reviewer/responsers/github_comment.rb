require_relative 'base'

module Lita
  module Handlers
    class Reviewer < Handler
      module Responsers
        class GithubComment < Base
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
    end
  end
end