require "paradocs/version"
require "paradocs/support"
require "paradocs/registry"
require "paradocs/field"
require "paradocs/results"
require "paradocs/schema"
require "paradocs/context"
require "paradocs/base_policy"
require 'ostruct'

module Paradocs
  def self.registry
    @registry ||= Registry.new
  end

  def self.policy(name, plcy = nil, &block)
    registry.policy name, plcy, &block
  end

  def self.config
    @config ||= OpenStruct.new(
      explicit_errors:  false,
      whitelisted_keys: []
    )
  end

  def self.configure
    yield self.config if block_given?
    self.config
  end
end

require 'paradocs/default_types'
require 'paradocs/policies'
