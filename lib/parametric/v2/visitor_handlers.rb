# frozen_string_literal: true

module Parametric
  module V2
    module VisitorHandlers
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def on(node_name, &block)
          name = node_name.is_a?(Symbol) ? node_name : :"#{node_name}_class"
          self.define_method("visit_#{name}", &block)
        end

        def visit(type, props = BLANK_HASH)
          new.visit(type, props)
        end
      end

      def visit(type, props = BLANK_HASH)
        method_name = type.respond_to?(:node_name) ? type.node_name : :"#{(type.is_a?(::Class) ? type : type.class)}_class"
        method_name = "visit_#{method_name}"
        if respond_to?(method_name)
          send(method_name, type, props)
        else
          on_missing_handler(type, props, method_name)
        end
      end

      def on_missing_handler(type, _props, method_name)
        raise "No handler for #{type.inspect} with :#{method_name}"
      end
    end
  end
end
