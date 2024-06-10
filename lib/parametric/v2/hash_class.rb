# frozen_string_literal: true

require 'parametric/v2/steppable'
require 'parametric/v2/key'
require 'parametric/v2/static_class'
require 'parametric/v2/hash_map'
require 'parametric/v2/tagged_hash'

module Parametric
  module V2
    class HashClass
      include Steppable

      def initialize(schema = {})
        @_schema = wrap_keys_and_values(schema)
        freeze
      end

      # A Hash type with a specific schema.
      # Option 1: a Hash representing schema
      #
      #   Types::Hash[name: Types::String.present, age?: Types::Integer]
      #
      # Option 2: a Map with pre-defined types for all keys and values
      #
      #   Types::Hash[Types::String, Types::Integer]
      def schema(*args)
        case args
        in [::Hash => hash]
          self.class.new(_schema.merge(wrap_keys_and_values(hash)))
        in [Steppable => key_type, Steppable => value_type]
          HashMap.new(key_type, value_type)
        else
          raise ::ArgumentError, "unexpected value to Types::Hash#schema #{args.inspect}"
        end
      end

      alias [] schema

      def ast
        [
          :hash,
          BLANK_HASH,
          _schema.map do |(k, v)|
            [k.ast, v.ast]
          end
        ]
      end

      # Hash#merge keeps the left-side key in the new hash
      # if they match via #hash and #eql?
      # we need to keep the right-side key, because even if the key name is the same,
      # it's optional flag might have changed
      def +(other)
        raise ArgumentError, "expected a HashClass, got #{other.class}" unless other.is_a?(HashClass)

        self.class.new(merge_rightmost_keys(_schema, other._schema))
      end

      def &(other)
        raise ArgumentError, "expected a HashClass, got #{other.class}" unless other.is_a?(HashClass)

        intersected_keys = other._schema.keys & _schema.keys
        intersected = intersected_keys.each.with_object({}) do |k, memo|
          memo[k] = other.at_key(k)
        end

        self.class.new(intersected)
      end

      def tagged_by(key, *types)
        TaggedHash.new(self, key, types)
      end

      def at_key(a_key)
        _schema[Key.wrap(a_key)]
      end

      def to_h = _schema

      private def _inspect
        %(#{name}[#{_schema.map { |(k, v)| [k.inspect, v.inspect].join(':') }.join(' ')}])
      end

      def call(result)
        return result.halt(errors: 'must be a Hash') unless result.value.is_a?(::Hash)
        return result unless _schema.any?

        input = result.value
        errors = {}
        field_result = BLANK_RESULT.dup
        output = _schema.each.with_object({}) do |(key, field), ret|
          key_s = key.to_sym
          if input.key?(key_s)
            r = field.call(field_result.reset(input[key_s]))
            errors[key_s] = r.errors unless r.success?
            ret[key_s] = r.value
          elsif !key.optional?
            r = field.call(BLANK_RESULT)
            errors[key_s] = r.errors unless r.success?
            ret[key_s] = r.value unless r.value == Undefined
          end
        end

        errors.any? ? result.halt(output, errors:) : result.success(output)
      end

      protected

      attr_reader :_schema

      private

      def wrap_keys_and_values(hash)
        case hash
        when ::Array
          hash.map { |e| wrap_keys_and_values(e) }
        when ::Hash
          hash.each.with_object({}) do |(k, v), ret|
            ret[Key.wrap(k)] = wrap_keys_and_values(v)
          end
        when Callable
          hash
        else #  leaf values
          StaticClass.new(hash)
        end
      end

      def merge_rightmost_keys(hash1, hash2)
        hash2.each.with_object(hash1.clone) do |(k, v), memo|
          # assigning a key that already exist with #hash and #eql
          # leaves the original key instance in place.
          # but we want the hash2 key there, because its optionality could have changed.
          memo.delete(k) if memo.key?(k)
          memo[k] = v
        end
      end
    end
  end
end
