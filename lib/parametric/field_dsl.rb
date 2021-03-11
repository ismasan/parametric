# frozen_string_literal: true

require "parametric/maybe_policy"

module Parametric
  # Field DSL
  # host instance must implement:
  # #meta(options Hash)
  # #policy(key Symbol) self
  #
  module FieldDSL
    def required
      policy :required
    end

    def present
      required.policy :present
    end

    def declared
      policy :declared
    end

    def options(opts)
      policy :options, opts
    end

    def maybe(key, *args)
      policy MaybePolicy.new(lookup(key, args))
    end
  end
end
