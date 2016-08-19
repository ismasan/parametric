module Parametric
  # Field DSL
  # host instance must implement:
  # #meta(options Hash)
  # #validate(key Symbol) self
  # #registry() Registry
  #
  module FieldDSL
    def required
      meta required: true
      validate :required
    end

    def present
      required.validate :present
    end

    def options(opts)
      meta options: opts
      validate :options, opts
    end

    def type(t)
      meta type: t
      validate(t) if registry.policies.key?(t)
      self
    end
  end
end
