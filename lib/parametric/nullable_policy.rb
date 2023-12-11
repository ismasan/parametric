# frozen_string_literal: true

module Parametric
  # A policy that allows a field to be nullable.
  # Fields with nil values are not processed further, and the value is returned as-is.
  # @example
  #   field(:age).nullable.type(:integer)
  #   field(:age).nullable.type(:integer).required
  #
  class NullablePolicy
    def meta_data; {}; end

    def build(key, value, payload:, context:)
      Runner.new(key, value, payload, context)
    end

    class Runner
      def initialize(key, value, payload, context)
        @key = key
        @value = value
        @payload = payload
        @context = context
      end

      # Should this policy run at all?
      # returning [false] halts the field policy chain.
      # @return [Boolean]
      def eligible?
        @payload.key?(@key) && !@value.nil?
      end

      # If this policy is not eligible, should the key and value be included in the output?
      # @return [Boolean]
      def include_non_eligible_in_ouput?
        true
      end

      # If [false], add [#message] to result errors and halt processing field.
      # @return [Boolean]
      def valid?
        true
      end

      # Coerce the value, or return as-is.
      # @return [Any]
      def value
        @value
      end

      # Error message for this policy
      # @return [String]
      def message
        ''
      end
    end
  end
end
