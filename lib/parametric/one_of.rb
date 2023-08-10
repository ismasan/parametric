# frozen_string_literal: true

module Parametric
  class OneOf
    def initialize(&block)
      @index = ->(payload) { payload }
      @matchers = {}
      block.call(self) if block_given?
      freeze
    end

    def message
      'could not match any sub-schema'
    end

    def index_by(callable = nil, &block)
      callable = ->(payload) { payload[callable] } if callable.is_a?(Symbol)
      @index = callable || block
    end

    def on(key, schema)
      @matchers[key] = schema
    end

    def eligible?(value, key, payload)
      payload.key?(key)
    end

    def coerce(value, key, context)
      value
    end

    def valid?(value, key, payload)
      @matchers.key?(payload[key])
    end

    def meta_data
      { one_of: @matchers.keys }
    end
  end
end
