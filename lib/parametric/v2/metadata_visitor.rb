# frozen_string_literal: true

require 'parametric/v2/visitor_handlers'

module Parametric
  module V2
    class MetadataVisitor
      include VisitorHandlers

      def self.call(type)
        new.visit(type)
      end

      def on_missing_handler(type, props, method_name)
        return props.merge(type: type) if type.class == Class

        puts "Missing handler for #{type.inspect} with props #{props.inspect} and :method_name #{method_name}"
        props
      end

      on(:pipeline) do |type, props|
        visit(type.type, props)
      end

      on(:step) do |type, props|
        props.merge(type._metadata)
      end

      on(::Regexp) do |type, props|
        props.merge(pattern: type)
      end

      on(::Range) do |type, props|
        props.merge(match: type)
      end

      on(:match) do |type, props|
        visit(type.matcher, props)
      end

      on(:hash) do |type, props|
        props.merge(type: Hash)
      end

      on(:and) do |type, props|
        left = visit(type.left)
        right = visit(type.right)
        type = right[:type] || left[:type]
        props = props.merge(left).merge(right)
        props = props.merge(type:) if type
        props
      end

      on(:or) do |type, props|
        child_metas = [visit(type.left), visit(type.right)]
        types = child_metas.map { |child| child[:type] }.flatten.compact
        types = types.first if types.size == 1
        child_metas.reduce(props) do |acc, child|
          acc.merge(child)
        end.merge(type: types)
      end

      on(:value) do |type, props|
        visit(type.value, props)
      end

      on(:transform) do |type, props|
        props.merge(type: type.target_type)
      end

      on(:static) do |type, props|
        visit(type.value, props)
      end

      on(:rules) do |type, props|
        type.rules.reduce(props) do |acc, rule|
          acc.merge(rule.name => rule.arg_value)
        end
      end

      on(:boolean) do |type, props|
        props.merge(type: 'boolean')
      end

      on(:metadata) do |type, props|
        props.merge(type.metadata)
      end

      on(:hash_map) do |type, props|
        props.merge(type: Hash)
      end

      on(:constructor) do |type, props|
        visit(type.type, props)
      end

      on(:array) do |type, props|
        props.merge(type: Array)
      end

      on(:tuple) do |type, props|
        props.merge(type: Array)
      end

      on(:tagged_hash) do |type, props|
        props.merge(type: Hash)
      end
    end
  end
end
