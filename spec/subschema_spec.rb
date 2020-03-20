require 'spec_helper'
require "paradocs/dsl"

describe "schemes with subschemes" do
  let(:validation_class) do
    Class.new do
      include Paradocs::DSL

      schema(:request) do
        field(:action).present.options([:update, :delete])
        subschema_by(:action) do |action|
          action == :update ? :update_schema : :generic_schema
        end
      end

      subschema_for(:request, name: :update_schema) do
        field(:event).present
      end

      subschema_for(:request, name: :generic_schema) do
        field(:generic_field).present
      end

      def self.validate(schema_name, data)
        schema(schema_name).resolve(data)
      end
    end
  end

  let(:update_request) {
    {
      action: :update,
      event:  "test"
    }
  }

  it "invokes necessary subschema based on condition" do
    valid_result = validation_class.validate(:request, update_request)
    expect(valid_result.output).to eq(update_request)
    expect(valid_result.errors).to eq({})

    failed_result = validation_class.validate(:request, {action: :update, generic_field: "test"})

    expect(failed_result.errors).to eq({"$.event"=>["is required"]})
    expect(failed_result.output).to eq({action: :update, event: nil})
  end

  describe "nested subschemes" do
    let(:schema) do
      Paradocs::Schema.new do
        field(:action).present.options([:update, :delete]).mutates_schema! do |value, key, payload|
          value == :update ? :update_schema : :generic_schema
        end
        field(:event).declared.type(:string)

        subschema(:generic_schema) do
          field(:generic_field).present
        end

        subschema(:update_schema) do
          field(:event).present.mutates_schema! do |value, key, payload|
            value == :go_deeper ? :very_deep_schema : :deep_update_schema
          end
          field(:update_field).present
          subschema(:deep_update_schema) do
            field(:field_from_deep_schema).required
          end

          subschema(:very_deep_schema) do
            field(:a_hash).type(:object).present.schema do
              field(:key).present.mutates_schema! { :draft_subschema }
              subschema(:draft_subschema) do
                field(:another_event).present.type(:boolean)
              end
            end
          end
        end
      end
    end

    context "update_schema -> deep_update_schema" do
      let(:payload) {
        {
          action:                 :update,
          event:                  :must_be_present,
          update_field:           1,
          field_from_deep_schema: nil
        }
      }

      it "builds schema as expected" do
        result = schema.resolve(payload)
        expect(result.output).to eq(payload)
        expect(result.errors).to eq({})
      end

      it "fails when validation fails in subschemas" do
        result = schema.resolve(payload.merge(action: :delete))
        expect(result.output).to eq(action: :delete, event: "must_be_present", generic_field: nil)
        expect(result.errors).to eq("$.generic_field"=>["is required"])
      end

      it "overwrites fields: subschema field overwrites parent field" do
        payload.delete(:event)
        result = schema.resolve(payload)
      end
    end

    context "update_schema -> very_deep_schema -> draft_subschema" do
      let(:payload) {
        {
          action:         :update,
          event:          :go_deeper,
          update_field:   1,
          a_hash:       {
            key:           :value,
            another_event: true
          }
        }
      }

      it "builds schema as expected"  do
        result = schema.resolve(payload)
        expect(result.output).to eq(payload)
        expect(result.errors).to eq({})
      end

      it "fails when payload doesn't suit just built schema" do
        payload[:a_hash] = {key: :random}
        result = schema.resolve(payload)
        payload[:a_hash][:another_event] = nil
        expect(result.output).to eq(payload)
        expect(result.errors).to eq({"$.a_hash.another_event"=>["is required"]})
      end
    end
  end
end
