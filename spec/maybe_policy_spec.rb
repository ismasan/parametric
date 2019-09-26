require 'spec_helper'

describe 'maybe policy' do
  specify do
    schema = Parametric::Schema.new do
      field(:age).maybe(:integer)
    end

    expect(schema.resolve({ age: 10 }).output[:age]).to eq 10
    expect(schema.resolve({ age: '10' }).output[:age]).to eq 10
    expect(schema.resolve({ age: nil }).output[:age]).to eq nil
    expect(schema.resolve({ nope: 1 }).output.key?(:age)).to be false
  end
end
