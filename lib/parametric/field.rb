# frozen_string_literal: true

require "parametric/field_dsl"

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
        r = sc.visit(meta_key, &visitor)
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
        if !policy.eligible?(value, key, payload)
          eligible = policy.include_non_eligible_in_ouput?
          if has_default?
            eligible = true
            value = default_block.call(key, payload, context)
          end
          break
        else
          value = resolve_one(policy, value, context)
          if !policy.valid?(value, key, payload)
            eligible = true # eligible, but has errors
            context.add_error policy.message
            break # only one error at a time
          end
        end
      end

      Result.new(eligible, value)
    end

    protected

    attr_reader :policies

    private

    attr_reader :registry, :default_block

    def resolve_one(policy, value, context)
      begin
        policy.coerce(value, key, context)
      rescue StandardError => e
        context.add_error e.message
        value
      end
    end

    def has_default?
      !!default_block && !meta_data[:skip_default]
    end

    def lookup(key, args)
      obj = key.is_a?(Symbol) ? registry.policies[key] : key

      raise ConfigurationError, "No policies defined for #{key.inspect}" unless obj

      pol = obj.respond_to?(:new) ? obj.new(*args) : obj
      adapt_policy(pol, key)
    end

    # Decorate policies to implement latest interface, if some
    # methods are missing.
    def adapt_policy(pol, key)
      pol = PolicyWithKey.new(pol, key)
      pol = PolicyWithIncludeNonEligible.new(pol) unless pol.respond_to?(:include_non_eligible_in_ouput?)
      pol
    end

    class PolicyWithIncludeNonEligible < SimpleDelegator
      def include_non_eligible_in_ouput?
        false
      end
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

