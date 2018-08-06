require 'spec_helper'

describe Parametric::Schema do
  it "expands fields dynamically" do
    schema = described_class.new do
      field(:title).type(:string).present
      expand(/^attr_(.+)/) do |match|
        field(match[1]).type(:string)
      end
      expand(/^validate_(.+)/) do |match|
        field(match[1]).type(:string).present
      end
    end

    out = schema.resolve({
      title: "foo",
      :"attr_Attribute 1" => "attr 1",
      :"attr_Attribute 2" => "attr 2",
      :"validate_valid_attr" => "valid",
      :"validate_invalid_attr" => "",
    })

    expect(out.output[:title]).to eq 'foo'
    expect(out.output[:"Attribute 1"]).to eq 'attr 1'
    expect(out.output[:"Attribute 2"]).to eq 'attr 2'

    expect(out.errors['$.invalid_attr']).to eq ['is required and value must be present']
  end
end
