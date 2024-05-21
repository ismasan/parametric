# frozen_string_literal: true

module Parametric
  module V2
    class JSONSchemaVisitor
      KNOWN_TYPES = {
        'object' => 'object',
        'boolean' => 'boolean',
        'string' => 'string',
        'integer' => 'integer',
        'numeric' => 'number',
        'number' => 'number',
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
      RegexpToString = ->(value) { value.respond_to?(:source) ? value.source : value.to_s}

      KNOWN_KEYS = {
        type: NormalizeType,
        properties: Noop,
        patternProperties: Noop,
        not: Noop,
        anyOf: Noop,
        allOf: Noop,
        description: Noop,
        enum: Noop,
        items: Noop,
        prefixItems: Noop,
        required: Noop,
        const: Noop,
        default: Noop,
        pattern: RegexpToString,
        exclusiveMinimum: Noop,
        exclusiveMaximum: Noop,
        minimum: Noop,
        maximum: Noop,
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

      def visit(node, prop = BLANK_HASH)
        method_name = "visit_#{node[0]}"
        if respond_to?(method_name)
          normalize_props(send(method_name, node, prop))
        else
          normalize_props(visit_metadata(node, prop))
        end
      end

      # TODO: figure out how
      # to represent recursive types in JSON Schema
      def visit_deferred(node, prop = BLANK_HASH)
        BLANK_HASH
      end

      def visit_hash(node, _prop = BLANK_HASH)
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

      def visit_hash_map(node, _prop = BLANK_HASH)
        result = {
          type: 'object',
          patternProperties: {
            '.*' => visit(node[2][1])
          }
        }
      end

      # https://json-schema.org/understanding-json-schema/reference/conditionals
      def visit_tagged_hash(node, _prop = BLANK_HASH)
        result = {
          type: 'object',
          required: [],
          properties: {}
        }

        key = node[1][:key].to_s
        children = node[2].map { |child| visit(child) }
        key_enum = children.map { |child| child[:properties][key][:const] }
        key_type = children.map { |child| child[:properties][key][:type] }
        result[:required] << key
        result[:properties][key] = { type: key_type.first, enum: key_enum }
        result[:allOf] = children.map do |child|
          child_prop = child[:properties][key]

          {
            if: {
              properties: { key => { const: child_prop[:const], type: child_prop[:type] } }
            },
            then: child.except(:type)
          }
        end

        result
      end

      def visit_metadata(node, prop = BLANK_HASH)
        prop.merge(node[1])
      end

      def visit_leaf(node, prop = BLANK_HASH)
        prop.merge(node[1])
      end

      def visit_any(node, prop = BLANK_HASH)
        prop.merge(node[1])
      end

      def visit_key(node)
        node[1][:name]
      end

      def visit_rules(node, prop = BLANK_HASH)
        node[2].reduce(prop) do |acc, child|
          acc.merge(visit(child))
        end
      end

      def visit_is_a(node, prop = BLANK_HASH)
        prop.merge(type: node[1][:type].to_s.downcase)
      end

      def visit_included_in(node, prop = BLANK_HASH)
        prop.merge(enum: node[1][:options])
      end

      def visit_excluded_from(node, prop = BLANK_HASH)
        negation = prop[:not] || {}
        negation = negation.merge(enum: node[1][:excluded_from])
        prop.merge(not: negation)
      end

      def visit_gt(node, prop = BLANK_HASH)
        prop.merge(exclusiveMinimum: node[1][:gt])
      end

      def visit_gte(node, prop = BLANK_HASH)
        prop.merge(minimum: node[1][:gte])
      end

      def visit_lt(node, prop = BLANK_HASH)
        prop.merge(exclusiveMaximum: node[1][:lt])
      end

      def visit_lte(node, prop = BLANK_HASH)
        prop.merge(maximum: node[1][:lte])
      end

      def visit_eq(node, prop = BLANK_HASH)
        prop.merge(enum: node[1])
        value = node[1][:eq]
        (value == Parametric::V2::Undefined) ? prop : prop.merge(type: value.class.name.downcase, const: value)
      end

      def visit_or(node, prop = BLANK_HASH)
        any_of = node[2].map { |child| visit(child) }
        prop.merge(anyOf: any_of)
      end

      def visit_and(node, prop = BLANK_HASH)
        left = visit(node[2][0])
        right = visit(node[2][1])
        type = right[:type] || left[:type]
        prop = prop.merge(left).merge(right)
        prop = prop.merge(type: type) if type
        prop
      end

      def visit_not(node, prop = BLANK_HASH)
        prop.merge(not: visit(node[2][0]))
      end

      def visit_constructor(node, prop = BLANK_HASH)
        prop.merge(
          type: node[1][:constructor].name.downcase
        )
      end

      def visit_static(node, prop = BLANK_HASH)
        prop.merge(node[1])
      end

      def visit_value(node, prop = BLANK_HASH)
        prop.merge(node[1])
      end

      def visit_default(node, prop = BLANK_HASH)
        prop.merge(node[1]).merge(visit(node[2].first))
      end

      def visit_boolean(node, prop = BLANK_HASH)
        prop.merge(node[1])
      end

      def visit_array(node, _prop = BLANK_HASH)
        items = visit(node[2].first)
        {
          type: 'array',
          items: items
        }
      end

      def visit_tuple(node, _prop = BLANK_HASH)
        items = node[2].map { |child| visit(child) }

        {
          type: 'array',
          prefixItems: items
        }
      end

      def visit_format(node, prop = BLANK_HASH)
        pattern = node[1][:pattern]
        pattern = pattern.respond_to?(:source) ? pattern.source : pattern.to_s
        prop.merge(pattern:)
      end
    end
  end
end
