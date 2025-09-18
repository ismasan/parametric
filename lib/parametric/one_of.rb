# frozen_string_literal: true

module Parametric
  # Policy that validates a value against multiple schemas and chooses the first valid match.
  # 
  # OneOf is useful for polymorphic validation where a field can be one of several
  # different object structures. It tries each schema in order and returns the output
  # of the first schema that successfully validates the input.
  # 
  # @example Basic usage
  #   user_schema = Schema.new { field(:name).type(:string).present }
  #   admin_schema = Schema.new { field(:role).type(:string).options(['admin']) }
  #   
  #   schema = Schema.new do |sc, _|
  #     sc.field(:person).type(:object).one_of(user_schema, admin_schema)
  #   end
  # 
  # @example With Struct
  #   class MyStruct
  #     include Parametric::Struct
  #
  #     schema do
  #       field(:data).type(:object).one_of(schema1, schema2, schema3)
  #     end
  #   end
  class OneOf
    # Initialize with an array of schemas to validate against
    # 
    # @param schemas [Array<Schema>] Array of Parametric::Schema objects
    def initialize(schemas = [])
      @schemas = schemas
    end

    # Build a Runner instance for this policy (PolicyFactory interface)
    # 
    # @param key [Symbol] The field key being validated
    # @param value [Object] The value to validate
    # @param payload [Hash] The full input payload
    # @param context [Object] Validation context
    # @return [Runner] A new Runner instance
    def build(key, value, payload:, context:)
      Runner.new(@schemas, key, value, payload, context)
    end

    # Return metadata about this policy
    # 
    # @return [Hash] Metadata hash with type and schema information
    def meta_data
      { type: :object, schema: @schemas }
    end

    # Runner handles the actual validation logic for OneOf policy.
    # 
    # It validates the input value against each schema in order and determines
    # which one(s) are valid. The policy succeeds if exactly one schema validates
    # the input, and fails if zero or multiple schemas are valid.
    class Runner
      # Initialize the runner with validation parameters
      # 
      # @param schemas [Array<Schema>] Schemas to validate against
      # @param key [Symbol] Field key being validated
      # @param value [Object] Value to validate
      # @param payload [Hash] Full input payload
      # @param context [Object] Validation context
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

      # Validates that exactly one schema matches the input value.
      # 
      # The validation fails if:
      # - No schemas validate the input (invalid data)
      # - Multiple schemas validate the input (ambiguous match)
      # 
      # @return [Boolean] true if exactly one schema validates the input
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

      # Returns the validated and coerced value from the first matching schema.
      # 
      # This method triggers the validation process by resolving the input value
      # against each schema. If a valid schema is found, its coerced output is
      # returned. Otherwise, the raw value is returned unchanged.
      # 
      # @return [Object] The coerced value from the first valid schema, or raw value if none match
      def value
        @value ||= begin
          @results = @schemas.map do |schema|
            schema.resolve(@raw_value)
          end
          first_valid = @results.find(&:valid?)
          first_valid ? first_valid.output : @raw_value
        end
      end

      # Error message when validation fails
      # 
      # @return [String, nil] Error message if validation failed, nil if valid
      def message
        @message
      end
    end
  end
end
