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
      def filter!(payload, source_schema)
        schema  = source_schema.clone
        context = Context.new(nil, Top.new, @environment, source_schema.subschemes.clone)
        # after source_schema.clone the cloned instance is losing parent's proprietes.
        # in this case after clone is losing #subschemes
        # TODO: Investigate and fix!
        resolve(payload, schema, context)
      end

      def resolve(payload, schema, context)
        filtered_payload = {}

        payload.dup.each do |key, value|
          key = key.to_sym
          update_schema_fields(schema, context, key, payload[key]) if schema.subschemes_identifiers[key]

          if value.is_a?(Hash)
            field_schema = find_schema_by(schema, key)
            value        = resolve(value, field_schema, context)
          elsif value.is_a?(Array)
            value = value.map do |v|
              if v.is_a?(Hash)
                field_schema = find_schema_by(schema, key)
                resolve(v, field_schema, context)
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

      def update_schema_fields(schema, context, key, value)
        new_schema_name = schema.subschemes_identifiers[key].call(value)
        return unless new_schema_name

        new_schema = new_schema_name.is_a?(Schema) ? new_schema_name : context.subschemes[new_schema_name]
        return unless new_schema

        context = context.subschema_reduce!(new_schema_name)

        schema.fields.merge!(new_schema.fields)
        schema.subschemes_identifiers.merge!(new_schema.subschemes_identifiers)
      end

      def find_schema_by(schema, key)
        meta_data = get_meta_data(schema, key)
        meta_data[:schema]
      end

      def whitelisted?(schema, key)
        meta_data = get_meta_data(schema, key)
        meta_data[:whitelisted] || whitelisted_keys.include?(key)
      end

      def get_meta_data(schema, key)
        return {} unless schema.respond_to?(:fields)
        return {} unless schema.fields[key]
        return {} unless schema.fields[key].respond_to?(:meta_data)
        meta_data = schema.fields[key].meta_data || {}
      end

      def whitelisted_keys
        Parametric.config.whitelisted_keys || []
      end
    end
  end
end
