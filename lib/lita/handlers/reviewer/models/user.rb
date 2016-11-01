# frozen_string_literal: true

require 'active_support/core_ext/object/blank'
require_relative 'base_model'

module Lita::Handlers::Reviewer
  class User < BaseModel
    USERS_KEY = 'users'

    attr_accessor :name
    attr_reader :redis

    def initialize(name:, level: nil, working_days: nil, options: {})
      @redis = options[:redis] || self.class.redis
      @name  = name
      @level = level
      @working_days = working_days
    end

    def exist?
      !redis.keys(key('*')).empty?
    end

    def level
      @level ||= redis.get(key(:level)).to_i
    end

    def save
      redis.set(key(:level), @level)
      redis.del(key(:working_days))
      redis.sadd(key(:working_days), @working_days)

      redis.sadd(USERS_KEY, @name)
      true
    end

    def update(level: nil, working_days: nil)
      return false unless exist?

      redis.set(key(:level), level) if level
      if working_days
        redis.del(key(:working_days))
        redis.sadd(key(:working_days), working_days)
      end

      true
    end

    def delete
      [:level, :working_days].each do |field|
        redis.del(key(field))
      end
      redis.srem(USERS_KEY, name)
      true
    end

    def screen_name
      # "@#{name}"
      name.to_s
    end

    def working_days
      @working_days ||= redis.smembers(key(:working_days)).map(&:to_i)
    end

    def working_today?
      working_days.include?(DateTime.now.wday)
    end

    private

    def key(field = nil)
      "#{USERS_KEY}:#{name}#{field.present? ? ':' + field : ''}"
    end

    class << self
      attr_accessor :redis

      def init(redis:, **_kwargs)
        @redis = redis
      end

      def add(name:, level: 0, working_days: (1..5).to_a)
        user = new(name: name, level: level, working_days: working_days)
        user.save
      end

      def find(name)
        user = new(name: name)
        user.exist? ? user : nil
      end

      def list
        redis.smembers(USERS_KEY).map { |name| new(name: name) }
      end

      def to_text(users)
        users.map(&:name).join(', ')
      end
    end
  end
end
