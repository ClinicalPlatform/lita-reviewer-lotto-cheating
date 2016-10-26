require 'forwardable'
require 'octokit'
require_relative 'pullrequest'

module Lita
  module Handlers
    class Reviewer < Handler
      class Github
        extend Forwardable

        def_delegators :@client, :pull_request

        def initialize(access_token)
          @client = Octokit::Client.new(access_token: access_token)
        end

        def write_comment(pr, text)
          @client.add_comment(pr.repo, pr.number, text)
        end

        # display in status check
        def create_status(pr, title, text)
          @client.create_status(
            pr.repo, pr.latest_commit, :pending,
            context: title,
            description: text
          )
        end

        def pullrequests(repositories)
          repositories.map do |repository|
            repo_name =
              case repository
              when String then repository
              when Hash   then repository[:name]
              end
            options =
              case repository
              when Hash then { labels: repository[:labels].join(',') }
              else {}
              end

            repo   = Octokit::Repository.new(repo_name)
            pulls  = @client.pulls(repo_name)
            # NOTE `pulls` API can't filter by labels, so we take pullrequests from `issues` API
            issues = @client.issues(repo_name, options).select { |i| i.pull_request }

            # NOTE `issues` API responses can't have branch commits data for pullrequest,
            #      so we should use data from `pulls` API by matching them with ones from `issues` API
            issues.map { |issue| pulls.find { |pull| pull.number == issue.number } }
                  .reject(&:nil?)
          end.flatten
        end
      end
    end
  end
end
