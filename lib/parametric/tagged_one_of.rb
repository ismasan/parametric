# frozen_string_literal: true

module Parametric
  # A policy that allows you to select a sub-schema based on a value in the payload.
  # @example
  #
  #   user_schema = Parametric::Schema.new do |sc, _|
  #     field(:name).type(:string).present
  #     field(:age).type(:integer).present
  #   end
  #
  #   company_schema = Parametric::Schema.new do
  #     field(:name).type(:string).present
  #     field(:company_code).type(:string).present
  #   end
  #
  #   schema = Parametric::Schema.new do |sc, _|
  #      # Use :type field to locate the sub-schema to use for :sub
  #      sc.field(:type).type(:string)
  #
  #      # Use the :one_of policy to select the sub-schema based on the :type field above
  #      sc.field(:sub).type(:object).tagged_one_of do |sub|
  #        sub.index_by(:type)
  #        sub.on('user', user)
  #        sub.on('company', company)
  #      end
  #    end
  #
  #    # The schema will now select the correct sub-schema based on the value of :type
  #    result = schema.resolve(type: 'user', sub: { name: 'Joe', age: 30 })
  #
  # Instances can also be created separately and used as a policy:
  # @example
  #
  #   UserOrCompany = Parametric::TaggedOneOf.new do |sc, _|
  #     sc.index_by(:type)
  #     sc.on('user', user_schema)
  #     sc.on('company', company_schema)
  #   end
  #
  #   schema = Parametric::Schema.new do |sc, _|
  #     sc.field(:type).type(:string)
  #     sc.field(:sub).type(:object).policy(UserOrCompany)
  #   end
  class TaggedOneOf
    NOOP_INDEX = ->(payload) { payload }.freeze
    def initialize(index: NOOP_INDEX, matchers: {}, &block)
      @index = index
      @matchers = matchers
      @configuring = false
      if block_given?
        @configuring = true
        block.call(self)
        @configuring = false
      end
      freeze
    end

    def index_by(callable = nil, &block)
      if callable.is_a?(Symbol)
        key = callable
        callable = ->(payload) { payload[key] }
      end
      index = callable || block
      if configuring?
        @index = index
      else
        self.class.new(index:, matchers: @matchers)
      end
    end

    def on(key, schema)
      @matchers[key] = schema
    end

    # The [PolicyFactory] interface
    def build(key, value, payload:, context:)
      Runner.new(@index, @matchers, key, value, payload, context)
    end

    def meta_data
      { type: :object, one_of: @matchers }
    end

    private def configuring?
      @configuring
    end

    class Runner
      def initialize(index, matchers, key, value, payload, context)
        @matchers = matchers
        @key = key
        @raw_value = value
        @payload = payload
        @context = context
        @index_value = index.call(payload)
      end

      # Should this policy run at all?
      # returning [false] halts the field policy chain.
      # @return [Boolean]
      def eligible?
        true
      end

      # If [false], add [#message] to result errors and halt processing field.
      # @return [Boolean]
      def valid?
        has_sub_schema?
      end

      # Coerce the value, or return as-is.
      # @return [Any]
      def value
        @value ||= has_sub_schema? ? sub_schema.coerce(@raw_value, @key, @context) : @raw_value
      end

      # Error message for this policy
      # @return [String]
      def message
        "#{@value} is invalid. No sub-schema found for '#{@index_value}'"
      end

      private

      def has_sub_schema?
        @matchers.key?(@index_value)
      end

      def sub_schema
        @sub_schema ||= @matchers[@index_value]
      end
    end
  end
end
