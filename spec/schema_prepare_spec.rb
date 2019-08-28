require 'spec_helper'

describe Parametric::Schema do
  subject(:schema) do
    described_class.new do
      prepare do |payload, context|
        payload[:slug] = payload[:name].to_s.downcase.gsub(/\s+/, '-') unless payload[:slug]
        payload
      end

      field(:name).policy(:string).present
      field(:slug).policy(:string).present
      field(:variants).policy(:array).schema do
        prepare do |payload, context|
          payload[:slug] = "v: #{payload[:name].to_s.downcase}"
          payload
        end
        field(:name).policy(:string).present
        field(:slug).type(:string).present
      end
    end
  end

  it 'passes payload through prepare block, if defined' do
    result = schema.resolve({ name: 'A name', variants: [{ name: 'A variant' }] })
    expect(result.valid?).to be true
    expect(result.output[:slug]).to eq 'a-name'
    expect(result.output[:variants].first[:slug]).to eq 'v: a variant'
  end
end
