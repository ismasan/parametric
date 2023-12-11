# frozen_string_literal: true

require 'delegate'
require 'parametric/field_dsl'
require 'parametric/policy_adapter'
require 'parametric/tagged_one_of'

module Parametric
  class ConfigurationError < StandardError; end

  class Field
    include FieldDSL

    attr_reader :key, :meta_data
    Result = Struct.new(:eligible?, :value)

    def initialize(key, registry = Parametric.registry)
      @key = key
      @policies = []
      @registry = registry
      @default_block = nil
      @meta_data = {}
      @policies = []
    end

    def meta(hash = nil)
      @meta_data = @meta_data.merge(hash) if hash.is_a?(Hash)
      self
    end

    def default(value)
      meta default: value
      @default_block = (value.respond_to?(:call) ? value : ->(key, payload, context) { value })
      self
    end

    def policy(key, *args)
      pol = lookup(key, args)
      meta pol.meta_data
      policies << pol
      self
    end
    alias_method :type, :policy

    def tagged_one_of(instance = nil, &block)
      policy(instance || Parametric::TaggedOneOf.new(&block))
    end

    def schema(sc = nil, &block)
      sc = (sc ? sc : Schema.new(&block))
      meta schema: sc
      policy sc.schema
    end

    def from(another_field)
      meta another_field.meta_data
      another_field.policies.each do |plc|
        policies << plc
      end

      self
    end

    def has_policy?(key)
      policies.any? { |pol| pol.key == key }
    end

    def visit(meta_key = nil, &visitor)
      if sc = meta_data[:schema]
        r = sc.schema.visit(meta_key, &visitor)
        (meta_data[:type] == :array) ? [r] : r
      else
        meta_key ? meta_data[meta_key] : yield(self)
      end
    end

    def resolve(payload, context)
      eligible = payload.key?(key)
      value = payload[key] # might be nil

      if !eligible && has_default?
        eligible = true
        value = default_block.call(key, payload, context)
        return Result.new(eligible, value)
      end

      policies.each do |policy|
        begin
          pol = policy.build(key, value, payload:, context:)
          if !pol.eligible?
            eligible = pol.include_non_eligible_in_ouput?
            if has_default?
              eligible = true
              value = default_block.call(key, payload, context)
            end
            break
          else
            value = pol.value
            if !pol.valid?
              eligible = true # eligible, but has errors
              context.add_error pol.message
              break # only one error at a time
            end
          end
        rescue StandardError => e
          context.add_error e.message
          break
        end
      end

      Result.new(eligible, value)
    end

    protected

    attr_reader :policies

    private

    attr_reader :registry, :default_block

    def has_default?
      !!default_block && !meta_data[:skip_default]
    end

    def lookup(key, args)
      obj = key.is_a?(Symbol) ? registry.policies[key] : key

      raise ConfigurationError, "No policies defined for #{key.inspect}" unless obj

      obj = obj.new(*args) if obj.respond_to?(:new)
      obj = PolicyWithKey.new(obj, key)
      obj = PolicyAdapter.new(obj) unless obj.respond_to?(:build)

      obj
    end

    class PolicyWithKey < SimpleDelegator
      attr_reader :key

      def initialize(policy, key)
        super policy
        @key = key
      end
    end
  end
end

