# frozen_string_literal: true

module Parametric
  class Results
    attr_reader :output, :errors

    def initialize(output, errors)
      @output, @errors = output, errors
    end

    def valid?
      !errors.keys.any?
    end
  end
end
