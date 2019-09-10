# frozen_string_literal: true

require "spec_helper"
require "graphql/types/json"

describe GraphQL::Types::JSON do
  module JSONTypeTest
    class JsonObject < GraphQL::Schema::Object
      field :keys, [String], null: false
      field :values, [Integer], null: false
      field :json, GraphQL::Types::JSON, null: false
    end

    class Query < GraphQL::Schema::Object
      field :parseJson, JsonObject, null: true do
        argument :json, GraphQL::Types::JSON, required: true
      end

      def parse_json(json:)
        # JSON is parsed by the scalar, so it's already a Hash
        {
          keys: json.keys,
          values: json.values,
          json: json
        }
      end
    end

    class Schema < GraphQL::Schema
      query(JSONTypeTest::Query)
      if TESTING_INTERPRETER
        use GraphQL::Execution::Interpreter
      end
    end
  end

  describe "as an input" do
    def parse_json(json_str)
      query_str = <<-GRAPHQL
      query($json: JSON!){
        parseJson(json: $json) {
          keys
          values
        }
      }
      GRAPHQL
      full_res = JSONTypeTest::Schema.execute(query_str, variables: { json: json_str })
      full_res["errors"] || full_res["data"]["parseJson"]
    end

    it "parses valid json" do
      res = parse_json('{ "one": 1, "two": 2 }')
      expected_res = {
        "keys" => ['one', 'two'],
        "values" => [1, 2]
      }
      assert_equal(expected_res, res)
    end

    it "adds an error for invalid json" do
      expected_errors = ["Variable json of type JSON! was provided invalid value"]

      assert_equal expected_errors, parse_json("{").map { |e| e["message"] }
      assert_equal expected_errors, parse_json("xyz").map { |e| e["message"] }
      assert_equal expected_errors, parse_json(nil).map { |e| e["message"] }
    end
  end

  describe "as an output" do
    it "returns a string" do
      query_str = <<-GRAPHQL
      query($json: JSON!){
        parseJson(json: $json) {
          json
        }
      }
      GRAPHQL

      json_str = '{"one":1,"two":2}'
      full_res = JSONTypeTest::Schema.execute(query_str, variables: { json: json_str })
      assert_equal json_str, full_res["data"]["parseJson"]["json"]
    end
  end

  describe "structure" do
    it "is in introspection" do
      introspection_res = JSONTypeTest::Schema.execute <<-GRAPHQL
      {
        __type(name: "JSON") {
          name
          kind
        }
      }
      GRAPHQL

      expected_res = { "name" => "JSON", "kind" => "SCALAR"}
      assert_equal expected_res, introspection_res["data"]["__type"]
    end
  end
end
