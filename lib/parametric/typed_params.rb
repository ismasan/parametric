require 'parametric/params'
module Parametric
  module TypedParams
    def self.included(base)
      base.send(:include, Params)
      base.extend DSL
    end

    module DSL
      def integer(field_name, label = '', opts = {}, &block)
        param(field_name, label, opts.merge(coerce: :to_i), &block)
      end

      def string(field_name, label = '', opts = {}, &block)
        param(field_name, label, opts.merge(coerce: :to_s), &block)
      end

      def array(field_name, label = '', opts = {}, &block)
        param(field_name, label, opts.merge(multiple: true), &block)
      end
    end
  end
end