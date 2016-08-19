module Parametric
  # Field DSL
  # host instance must implement:
  # #meta(options Hash)
  # #policy(key Symbol) self
  #
  module FieldDSL
    def required
      meta required: true
      policy :required
    end

    def present
      required.policy :present
    end

    def options(opts)
      meta options: opts
      policy :options, opts
    end

    def type(t)
      meta type: t
      policy(t)
      self
    end
  end
end
