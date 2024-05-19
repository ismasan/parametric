# frozen_string_literal: true

require 'parametric/v2/metadata_visitor'

module Parametric
  module V2
    class MetadataVisitor
      def self.call(ast)
        new.visit(ast)
      end

      def visit(node, prop = BLANK_HASH)
        case node[0]
        when :and
          visit_and(node, prop)
        when :or
          visit_or(node, prop)
        when :hash
          visit_hash(node, prop)
        when :hash_map
          visit_with_type(node, prop, 'hash')
        when :array
          visit_with_type(node, prop, 'array')
        when :deferred
          BLANK_HASH
        else
          visit_default(node, prop)
        end
      end

      def visit_and(node, prop)
        left = visit(node[2][0])
        right = visit(node[2][1])
        type = right[:type] || left[:type]
        prop = prop.merge(left).merge(right)
        prop[type:] if type
        prop
      end

      def visit_or(node, prop)
        child_metas = node[2].map { |child| visit(child) }
        types = child_metas.map { |child| child[:type] }.flatten.compact
        types = types.first if types.size == 1
        child_metas.reduce(prop) do |acc, child|
          acc.merge(child)
        end.merge(type: types)
      end

      def visit_hash(node, prop)
        prop.merge(type: 'hash')
      end

      def visit_default(node, prop)
        prop = prop.merge(node[1])
        node[2].reduce(prop) do |acc, child|
          acc.merge(visit(child))
        end
      end

      def visit_with_type(node, prop, type)
        visit_default(node, prop).merge(type:)
      end
    end
  end
end
