# frozen_string_literal: true

require 'active_support/core_ext/object/blank'
require 'reviewer_lotto_cheating/model'

module Lita::Handlers::ReviewerLottoCheating
  class User < Model
    USERS_KEY = 'users'

    attr_accessor :name
    attr_reader :redis

    def initialize(name:, level: nil, working_days: nil, options: {})
      @redis = options[:redis] || self.class.redis
      @name  = name
      @level = level
      @working_days = working_days
    end

    def delete
      [:level, :working_days].each do |field|
        redis.del(key(field))
      end
      redis.srem(USERS_KEY, name)
      true
    end

    def exist?
      redis.sismember(USERS_KEY, name)
    end

    def key(field = nil)
      "#{USERS_KEY}:#{name}#{field.present? ? ":#{field}" : ''}"
    end

    def level
      @level ||= (redis.get(key(:level)).to_i || 0)
    end

    def level=(level)
      @level = level
    end

    def save
      redis.set(key(:level), level)
      if working_days.present?
        redis.del(key(:working_days))
        redis.sadd(key(:working_days), working_days)
      end
      redis.sadd(USERS_KEY, name)
      true
    end

    def screen_name
      "@#{name}"
    end

    def update(level: nil, working_days: nil)
      self.level        = level if level
      self.working_days = working_days if working_days
      save
    end

    def working_days
      @working_days ||= redis.smembers(key(:working_days)).map(&:to_i)
    end

    def working_days=(working_days)
      @working_days = working_days
    end

    def working_today?
      working_days.include?(DateTime.now.wday)
    end

    class << self
      attr_accessor :redis

      def init(redis:, **_kwargs)
        @redis = redis
      end

      def upsert(name:, level: nil, working_days: nil)
        user = new(name: name)
        user.update(level: level, working_days: working_days)
      end

      def find(name)
        user = new(name: name)
        user.exist? ? user : nil
      end

      def list
        redis.smembers(USERS_KEY).map { |name| new(name: name) }
      end
    end
  end
end
