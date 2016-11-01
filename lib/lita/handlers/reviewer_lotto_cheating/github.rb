# frozen_string_literal: true

require 'forwardable'
require 'octokit'

module Lita::Handlers::ReviewerLottoCheating
  class Github
    extend Forwardable

    def_delegators :@client, :add_comment, :create_status, :pull_request

    def initialize(access_token)
      @client = Octokit::Client.new(access_token: access_token)
    end

    def write_comment(pr, text)
      @client.add_comment(pr.repo, pr.number, text)
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

        # NOTE `pulls` API can't filter it by labels, so we take pullrequests
        #      from `issues` API
        issues = @client.issues(repo_name, options)
                        .select(&:pull_request)

        # NOTE `issues` API responses can't include commits data of pullrequest,
        #      so we should pull data from `pulls` API by matching them
        #      with ones from `issues` API
        pulls  = @client.pulls(repo_name)

        issues.map { |issue| pulls.find { |pull| pull.number == issue.number } }
              .reject(&:nil?)
      end.flatten
    end
  end
end
