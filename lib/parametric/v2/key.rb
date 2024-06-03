# frozen_string_literal: true

module Parametric
  module V2
    class Key
      OPTIONAL_EXP = /(\w+)(\?)?$/

      def self.wrap(key)
        key.is_a?(Key) ? key : new(key)
      end

      attr_reader :to_sym

      def initialize(key, optional: false)
        key_s = key.to_s
        match = OPTIONAL_EXP.match(key_s)
        @key = match[1]
        @to_sym = @key.to_sym
        @optional = !match[2].nil? ? true : optional
        freeze
      end

      def to_s = @key

      def ast
        [:key, { name: @key, optional: @optional }, BLANK_ARRAY]
      end

      def hash
        @key.hash
      end

      def eql?(other)
        other.hash == hash
      end

      def optional?
        @optional
      end

      def inspect
        "#{@key}#{'?' if @optional}"
      end
    end
  end
end
