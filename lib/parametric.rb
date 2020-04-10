# frozen_string_literal: true

require "parametric/version"
require "parametric/registry"
require "parametric/field"
require "parametric/results"
require "parametric/schema"
require "parametric/context"

module Parametric

  def self.registry
    @registry ||= Registry.new
  end

  def self.policy(name, plcy = nil, &block)
    registry.policy name, plcy, &block
  end
end

require 'parametric/default_types'
require 'parametric/policies'
