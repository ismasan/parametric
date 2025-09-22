# frozen_string_literal: true

module Parametric
  # A policy wrapper that delegates type coercion and validation to external objects.
  #
  # This allows integration of custom types, domain objects, or value objects that
  # implement their own coercion and validation logic into Parametric schemas.
  #
  # The wrapped object must implement:
  # - `coerce(value)`: Method to convert input values to the desired type
  # - The returned object must have an `errors` method that returns validation errors
  #
  # @example Basic usage
  #   Money = Data.define(:amount, :currency) do
  #     def self.coerce(value)
  #       case value
  #       when Hash
  #         new(value[:amount], value[:currency])
  #       when String
  #         parts = value.split(' ')
  #         new(parts[0].to_f, parts[1])
  #       else
  #         new(value, 'USD')
  #       end
  #     end
  #
  #     def errors
  #       errors = {}
  #       errors[:amount] = ['must be positive'] if amount <= 0
  #       errors[:currency] = ['invalid'] unless %w[USD EUR GBP].include?(currency)
  #       errors
  #     end
  #   end
  #
  #   field(:price).wrap(Money)
  #
  # @see Field#wrap
  class Wrapper
    # Initialize the wrapper with a caster object.
    #
    # @param caster [Object] Object that responds to `coerce(value)` method
    def initialize(caster)
      @caster = caster
    end

    # Build a policy runner for this wrapper.
    #
    # @param key [Symbol] The field key being processed
    # @param value [Object] The input value to be coerced and validated
    # @param payload [Hash] The complete input payload (unused)
    # @param context [Context] The validation context (unused)
    # @return [Runner] A runner instance that handles the coercion and validation
    def build(key, value, payload:, context:)
      Runner.new(@caster, key, value)
    end

    # Return metadata about this policy.
    #
    # @return [Hash] Metadata hash containing the wrapper type
    def meta_data
      { type: @caster }
    end

    # Policy runner that executes the wrapper's coercion and validation logic.
    #
    # This class implements the policy runner interface required by Parametric's
    # policy system. It delegates coercion to the wrapper object and collects
    # validation errors from the coerced value.
    class Runner
      attr_reader :key, :value

      # Initialize the runner with coercion logic.
      #
      # @param caster [Object] Object that responds to `coerce(value)`
      # @param key [Symbol] The field key being processed
      # @param value [Object] The input value to be coerced and validated
      def initialize(caster, key, value)
        @caster = caster
        @key = key
        @value = caster.coerce(value)
        @errors = @value.errors
      end

      # Check if this policy should run.
      #
      # @return [Boolean] Always returns true for wrapper policies
      def eligible?
        true
      end

      # Check if the coerced value is valid.
      #
      # @return [Boolean] True if no validation errors, false otherwise
      def valid? = @errors.empty?

      # Generate a human-readable error message from validation errors.
      #
      # @return [String] Formatted error message combining all validation errors
      def message = @errors.map { |k, v| "#{k} #{v.join(', ')}" }.join('. ')
    end
  end
end
