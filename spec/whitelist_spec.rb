require 'spec_helper'
require "parametric/whitelist"
require "parametric/dsl"

describe "classes including Whitelist module" do
  class TestWhitelist
    include Parametric::DSL
    include Parametric::Whitelist

    schema(:request) do
      field(:data).present.type(:array).schema do
        field(:id).present.type(:string).whitelisted
        field(:name).present.type(:string)
        field(:empty_array).type(:array).schema do
          field(:id).whitelisted
        end
        field(:subschema_1).whitelisted
        subschema_by(:subschema_1) do |name|
          name.to_sym
        end
        field(:empty_hash).type(:array).schema do
          field(:id).whitelisted
        end
        field(:extra).schema do
          field(:id).present.type(:string).whitelisted
          field(:name).present.type(:string)
          field(:empty_string).present.type(:string)
        end
      end
    end

    subschema_for(:request, name: :subfield_1) do
      field(:subfield_1).present.type(:boolean).whitelisted
      field(:subschema_2)
      subschema_by(:subschema_2) do |name|
        name.to_sym
      end
    end

    subschema_for(:request, name: :subfield_2) do
      field(:subfield_2).present.type(:boolean).whitelisted
    end
  end

  describe ".filter!" do
    let(:schema) { TestWhitelist.schema(:request) }
    let(:input) {
      {
        "unexpected" => "test",
        from_config: "whitelisted",
        data: [
          "id" => 5,
          name: nil,
          unexpected: nil,
          empty_array: [],
          subschema_1: "subfield_1",
          subfield_1: true,
          subschema_2: "subfield_2",
          subfield_2: true,
          empty_hash: {},
          "extra" => {
            id: 6,
            name: "name",
            unexpected: "unexpected",
            empty_string: ""
          }
        ]
      }
    }

    before { Parametric.config.whitelisted_keys = [:from_config]}

    it "should filter not whitelisted attributes with different key's type" do
      whitelisted = TestWhitelist.new.filter!(input, schema)

      expect(whitelisted).to eq(
        {
          unexpected: "[FILTERED]",
          from_config: "whitelisted",
          data: [
            {
              id: 5,
              name: "[EMPTY]",
              unexpected: "[EMPTY]",
              empty_array: [],
              subschema_1: "subfield_1",
              subfield_1: true,
              subschema_2: "[FILTERED]",
              subfield_2: true,
              empty_hash: {},
              extra: {
                id: 6,
                name: "[FILTERED]",
                unexpected: "[FILTERED]",
                empty_string: "[EMPTY]"
              }
            }
          ]
        }
      )
    end
  end
end
