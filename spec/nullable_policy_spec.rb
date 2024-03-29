# frozen_string_literal: true

require 'spec_helper'

describe 'nullable policy' do
  specify 'dealing with nil values' do
    schema = Parametric::Schema.new do
      field(:age).nullable.type(:integer)
    end

    expect(schema.resolve({ age: 10 }).output[:age]).to eq 10
    expect(schema.resolve({ age: '10' }).output[:age]).to eq 10
    expect(schema.resolve({ age: nil }).output[:age]).to eq nil
    expect(schema.resolve({ age: false }).output[:age]).to be false
    expect(schema.resolve({ nope: 1 }).output.key?(:age)).to be true
  end

  specify 'with required/present types' do
    schema = Parametric::Schema.new do
      field(:age).nullable.type(:integer).present.policy(:gt, 9)
    end

    schema.resolve({ age: '10' }).tap do |r|
      expect(r.output[:age]).to eq 10
      expect(r.errors.any?).to be false
    end

    schema.resolve({ age: '7' }).tap do |r|
      expect(r.output[:age]).to eq 7
      expect(r.errors.any?).to be true
    end

    schema.resolve({ age: nil }).tap do |r|
      expect(r.output[:age]).to eq nil
      expect(r.errors.any?).to be false
    end

    schema.resolve({}).tap do |r|
      expect(r.output.key?(:age)).to be true
      expect(r.output[:age]).to eq nil
      expect(r.errors.any?).to be false
    end
  end

  specify 'interacting with custom types that validate' do
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
      field(:age).nullable.type(:validating_integer)
    end

    expect(schema.resolve({ age: 10 }).output[:age]).to eq 10
    expect(schema.resolve({ age: '10' }).output[:age]).to eq 10
    schema.resolve({ age: 'nope' }).tap do |r|
      expect(r.output[:age]).to eq 'nope'
      expect(r.errors.any?).to be true
    end
    schema.resolve({ age: nil }).tap do |r|
      expect(r.output.key?(:age)).to be(true)
      expect(r.output[:age]).to eq nil
      expect(r.errors.any?).to be false
    end
    expect(schema.resolve({ age: nil }).output[:age]).to eq nil
    expect(schema.resolve({ nope: 1 }).output.key?(:age)).to be true
  end

  specify 'interacting with required fields' do
    schema = Parametric::Schema.new do
      field(:age).nullable.type(:integer).required
    end

    result = schema.resolve({})
    expect(result.output.key?(:age)).to be(true)
    expect(result.output[:age]).to eq nil
    expect(result.errors['$.age']).to eq nil
  end

  specify 'copying policies via Field#from' do
    source_schema = Parametric::Schema.new do
      field(:age).nullable.type(:integer).required
    end

    target_schema = Parametric::Schema.new do |sc, _|
      source_schema.fields.each do |key, f|
        sc.field(key).from(f)
      end
    end

    result = target_schema.resolve({})
    expect(result.output[:age]).to eq nil
    expect(result.errors['$.age']).to eq nil
  end
end
