require 'spec_helper'

describe 'maybe policy' do
  specify 'dealing with nil values' do
    schema = Parametric::Schema.new do
      field(:age).maybe(:integer)
    end

    expect(schema.resolve({ age: 10 }).output[:age]).to eq 10
    expect(schema.resolve({ age: '10' }).output[:age]).to eq 10
    expect(schema.resolve({ age: nil }).output[:age]).to eq nil
    expect(schema.resolve({ age: false }).output[:age]).to be false
    expect(schema.resolve({ nope: 1 }).output.key?(:age)).to be false
  end

  specify 'interacting with types that validate' do
    Parametric.policy :validating_integer do
      exp = /^\d+$/

      validate do |value, _key, _context|
        !!(value.to_s =~ exp)
      end

      coerce do |value, _key, _context|
        if value.to_s =~ exp
          value.to_i
        else
          value
        end
      end

      message do
        'error!'
      end
    end

    schema = Parametric::Schema.new do
      field(:age).maybe(:validating_integer)
    end

    expect(schema.resolve({ age: 10 }).output[:age]).to eq 10
    expect(schema.resolve({ age: '10' }).output[:age]).to eq 10
    schema.resolve({ age: 'nope' }).tap do |r|
      expect(r.output[:age]).to eq 'nope'
      expect(r.errors.any?).to be true
    end
    schema.resolve({ age: nil }).tap do |r|
      expect(r.output[:age]).to eq nil
      expect(r.errors.any?).to be false
    end
    expect(schema.resolve({ age: nil }).output[:age]).to eq nil
    expect(schema.resolve({ nope: 1 }).output.key?(:age)).to be false
  end
end
