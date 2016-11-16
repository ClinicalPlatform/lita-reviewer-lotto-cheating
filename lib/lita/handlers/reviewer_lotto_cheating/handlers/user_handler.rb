# frozen_string_literal: true

require 'lita-keyword-arguments'
require 'reviewer_lotto_cheating/handler'
require 'reviewer_lotto_cheating/models/user'

module Lita::Handlers::ReviewerLottoCheating
  class UserHandler < Handler
    namespace 'reviewer_lotto_cheating'

    route /reviewer\s+list\s*/, :list_user,
          command: true,
          help: {
            'reviewer list' => t('help.list_user')
          }

    route /reviewer\s+add\s+(\S+)/, :add_user,
          command: true,
          kwargs: {
            level: { short: 'l' },
            working_days: { short: 'w' }
          },
          help: {
            'reviewer add USERNAME ' \
            '[-l | --level NUMBER] ' \
            '[-w | --working_days COMMA_SEPARATED_NUMBERS (0-6 Sunday is 0)]' \
              => t('help.add_user'),
          }

    route /reviewer\s+delete\s+(\S+)/, :delete_user,
      command: true,
      help: {
        'reviewer delete USERNAME'=> t('help.delete_user')
      }

    def list_user(response)
      users = User.list
      width = users.inject(0) { |w, u| w > u.name.length ? w : u.name.length }
      text  = users.map do |u|
        sprintf("- %-#{width}s  level:%2d  working_days: %s",
                u.name, u.level,
                u.working_days.map { |wday| t('date.abbr_day_names')[wday] })
      end.join("\n")

      response.reply(text)
    end

    def add_user(response)
      name = response.matches[0][0]
      kwargs = build_arguments(
        response.extensions[:kwargs].merge(name: name)
      )
      User.add_or_update(kwargs)
      response.reply(t('message.add_or_updated', name: name))
    end

    def delete_user(response)
      name = response.matches[0][0]
      user = User.find(name)
      if user
        user.delete
        response.reply(t('message.deleted', name: name))
      else
        response.reply(t('error.user_not_found', name: name))
      end
    end

    private

    def build_arguments(options)
      kwargs = {}
      kwargs[:name]         = options[:name]
      kwargs[:level]        = options[:level]
      kwargs[:working_days] = options[:working_days]&.split(',')
      # delete fields whose value is `nil` or `""`
      kwargs.reject { |_, v| !v || v&.empty? }
    end

    Lita.register_handler(self)
  end
end
