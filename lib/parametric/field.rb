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
    alias_method :rule, :policy

    def schema(sc = nil, &block)
      sc = (sc ? sc : Schema.new(&block))
      meta schema: sc
      policy sc.schema
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
        payload[key] = value
      end
      policies.each do |policy|
        # pass schema additional data to the each policy
        policy.environment = context.environment
        if !policy.eligible?(value, key, payload)
          eligible = false
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

    private
    attr_reader :policies, :registry, :default_block

    def resolve_one(policy, value, context)
      begin
        policy.coerce(value, key, context)
      rescue *Parametric.config.custom_errors => e
        raise e
      rescue StandardError => e
        context.add_error e.message
        value
      end
    end

    def has_default?
      !!default_block
    end

    def lookup(key, args)
      obj = key.is_a?(Symbol) ? registry.policies[key] : key

      raise ConfigurationError, "No policies defined for #{key.inspect}" unless obj
      obj.respond_to?(:new) ? obj.new(*args) : obj
    end
  end
end

