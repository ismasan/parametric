module Parametric
  module Whitelist
    # Example
    #   class Foo
    #     include Parametric::DSL
    #     include Parametric::Whitelist
    #
    #     schema(:test) do
    #       field(:title).type(:string).whitelisted
    #       field(:age).type(:integer).default(20)
    #     end
    #   end
    #
    #   foo    = Foo.new
    #   schema = foo.class.schema(:test)
    #   params = {title: "title", age: 25}
    #   foo.filter!(params, schema) # => {title: "title", age: "[FILTERED]"}
    #
    FILTERED = "[FILTERED]"
    EMPTY    = "[EMPTY]"

    def self.included(base)
      base.include(ClassMethods)
    end

    module ClassMethods
      def filter!(payload, schema)
        filtered_payload = {}

        payload.dup.each do |key, value|
          key = key.to_sym

          if value.is_a?(Hash)
            field_schema = find_schema_by(schema, value, key)
            value = filter!(value, field_schema)
          elsif value.is_a?(Array)
            value = value.map do |v|
              if v.is_a?(Hash)
                field_schema = find_schema_by(schema, value, key)
                filter!(v, field_schema)
              else
                v = FILTERED unless whitelisted?(schema, key)
                v
              end
            end
          else
            value = if value.nil? || value.try(:blank?) || value.try(:empty?)
              EMPTY
            elsif whitelisted?(schema, key)
              value
            else
              FILTERED
            end
            value
          end

          filtered_payload[key] = value
        end

        filtered_payload
      end

      private

      def find_schema_by(schema, value, key)
        meta_data = get_meta_data(schema, key)
        meta_data[:schema]
      end

      def whitelisted?(schema, key)
        meta_data = get_meta_data(schema, key)
        meta_data[:whitelisted]
      end

      def get_meta_data(schema, key)
        return {} unless schema.respond_to?(:fields)
        return {} unless schema.fields[key]
        return {} unless schema.fields[key].respond_to?(:meta_data)
        meta_data = schema.fields[key].meta_data || {}
      end
    end
  end
end
