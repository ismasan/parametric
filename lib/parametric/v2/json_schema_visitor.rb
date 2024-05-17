# frozen_string_literal: true

module Parametric
  module V2
    class JSONSchemaVisitor
      KNOWN_TYPES = {
        'object' => 'object',
        'boolean' => 'boolean',
        'string' => 'string',
        'integer' => 'integer',
        'float' => 'number',
        'null' => 'null',
        'nilclass' => 'null',
        'trueclass' => 'boolean',
        'falseclass' => 'boolean',
        'array' => 'array',
      }.freeze

      NormalizeType = proc do |type|
        KNOWN_TYPES.fetch(type) { puts("WARNING: unknown type '#{type}'"); type }
      end

      Noop = ->(value) { value }

      KNOWN_KEYS = {
        type: NormalizeType,
        properties: Noop,
        patternProperties: Noop,
        not: Noop,
        anyOf: Noop,
        description: Noop,
        enum: Noop,
        items: Noop,
        required: Noop,
        const: Noop,
        default: Noop,
        pattern: Noop,
      }.freeze

      def self.call(ast)
        {
          '$schema' => 'http://json-schema.org/draft-08/schema#',
        }.merge(new.visit(ast))
      end

      def normalize_props(props)
        props.each_with_object({}) do |(key, value), acc|
          if(normalizer = KNOWN_KEYS[key.to_sym])
            acc[key] = normalizer.call(value)
          else
            puts "WARNING: Unknown key #{key}"
          end
        end
      end

      def visit(node, prop = {})
        method_name = "visit_#{node[0]}"
        normalize_props(send(method_name, node, prop))
      end

      def visit_hash(node, _prop = {})
        result = {
          type: 'object',
          required: [],
          properties: {}
        }

        node[2].each do |pair|
          key_node, value_node = pair
          key_name = visit_key(key_node)
          result[:required] << key_name unless key_node[1][:optional]
          result[:properties][key_name] = visit(value_node)
        end

        result
      end

      def visit_hash_map(node, _prop = {})
        result = {
          type: 'object',
          patternProperties: {
            '.*' => visit(node[2][1])
          }
        }
      end

      def visit_metadata(node, prop = {})
        prop.merge(node[1])
      end

      def visit_leaf(node, prop = {})
        prop.merge(node[1])
      end

      def visit_any(node, prop = {})
        prop.merge(node[1])
      end

      def visit_key(node)
        node[1][:name]
      end

      def visit_rules(node, prop = {})
        node[2].reduce(prop) do |acc, child|
          acc.merge(visit(child))
        end
      end

      def visit_is_a(node, prop = {})
        prop.merge(type: node[1][:type].to_s.downcase)
      end

      def visit_included_in(node, prop = {})
        prop.merge(enum: node[1][:options])
      end

      def visit_eq(node, prop = {})
        prop.merge(enum: node[1])
        value = node[1][:eq]
        (value == Parametric::V2::Undefined) ? prop : prop.merge(type: value.class.name.downcase, const: value)
      end

      def visit_or(node, prop = {})
        any_of = node[2].map { |child| visit(child) }
        prop.merge(anyOf: any_of)
      end

      def visit_and(node, prop = {})
        left = visit(node[2][0])
        right = visit(node[2][1])
        type = right[:type] || left[:type]
        prop = prop.merge(left).merge(right)
        prop = prop.merge(type: type) if type
        prop
      end

      def visit_not(node, prop = {})
        prop.merge(not: visit(node[2][0]))
      end

      def visit_static(node, prop = {})
        prop.merge(node[1])
      end

      def visit_value(node, prop = {})
        prop.merge(node[1])
      end

      def visit_default(node, prop = {})
        prop.merge(node[1]).merge(visit(node[2].first))
      end

      def visit_boolean(node, prop = {})
        prop.merge(node[1])
      end

      def visit_array(node, _prop = {})
        items = visit(node[2].first)
        {
          type: 'array',
          items: items
        }
      end

      def visit_format(node, prop = {})
        pattern = node[1][:pattern]
        pattern = pattern.respond_to?(:source) ? pattern.source : pattern.to_s
        prop.merge(pattern:)
      end
    end
  end
end
