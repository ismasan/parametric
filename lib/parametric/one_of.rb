# frozen_string_literal: true

module Parametric
  class OneOf
    def initialize(schemas = [])
      @schemas = schemas
    end

    # The [PolicyFactory] interface
    def build(key, value, payload:, context:)
      Runner.new(@schemas, key, value, payload, context)
    end

    def meta_data
      { type: :object, one_of: @schemas.map(&:meta_data) }
    end

    class Runner
      def initialize(schemas, key, value, payload, context)
        @schemas = schemas
        @key = key
        @raw_value = value
        @payload = payload
        @context = context
        @results = []
        @message = nil
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
        value
        valids = @results.select(&:valid?)
        if valids.size > 1
          @message = "#{@raw_value} is invalid. Multiple valid sub-schemas found"
        elsif valids.empty?
          @message = "#{@raw_value} is invalid. No valid sub-schema found"
        end
        @message.nil?
      end

      # Coerce the value, or return as-is.
      # @return [Any]
      def value
        @value ||= begin
          @results = @schemas.map do |schema|
            schema.resolve(@raw_value)
          end
          first_valid = @results.find(&:valid?)
          first_valid ? first_valid.output : @raw_value
        end
      end

      # Error message for this policy
      # @return [String]
      def message
        @message
      end
    end
  end
end
