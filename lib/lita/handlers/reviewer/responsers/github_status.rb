module Lita
  module Handlers
    class Reviewer < Handler
      module Responsers
        # display in status check
        class GithubStatusCheck < Base
          attr_reader :github

          def initialize(_redis, github)
            @github = github
          end

          def call(pr, reviewers)
            github.create_status(
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
