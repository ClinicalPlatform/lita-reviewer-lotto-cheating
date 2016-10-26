require_relative 'base'

module Lita
  module Handlers
    class Reviewer < Handler
      module Responsers
        # display in status check
        class GithubStatusCheck < Base
          def initialize(github:, **kwargs)
            @github = github
          end

          def on_assigned(pr, reviewers)
            text = t('message.assigned_reviewers.comment',
                     reviewers: User.to_text(reviewers))
            @github.create_status(
              pr.repo, pr.latest_commit, :pending,
              context: t('application_name'),
              description: text
            )
          end
        end
      end
    end
  end
end