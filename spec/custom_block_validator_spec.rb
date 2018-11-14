require 'spec_helper'

describe 'custom block validator' do
  Parametric.policy :validate_if do
    eligible do |options, value, key, payload|
      options.all? do |key, value|
        payload[key] == value
      end
    end
  end

  it 'works if I just define an :eligible block' do
    schema = Parametric::Schema.new do
      field(:name).policy(:validate_if, age: 40).present
      field(:age).type(:integer)
    end

    expect(schema.resolve(age: 30).errors.any?).to be false
    expect(schema.resolve(age: 40).errors.any?).to be true # name is missing
  end
end
