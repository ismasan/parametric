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
  end

  describe ".filter!" do
    let(:schema) { TestWhitelist.schema(:request) }
    let(:input) {
      {
        unexpected: "test",
        data: [
          id: 5,
          name: nil,
          unexpected: nil,
          empty_array: [],
          empty_hash: {},
          extra: {
            id: 6,
            name: "name",
            unexpected: "unexpected",
            empty_string: ""
          }
        ]
      }
    }
    it "should filter not whitelisted attributes" do
      whitelisted = TestWhitelist.new.filter!(input, schema)

      expect(whitelisted).to eq(
        {
          unexpected: "[FILTERED]",
          data: [
            {
              id: 5,
              name: "[EMPTY]",
              unexpected: "[EMPTY]",
              empty_array: [],
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
