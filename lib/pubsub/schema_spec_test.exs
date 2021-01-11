defmodule GenesisPubSub.SchemaSpecTest do
  use ExUnit.Case, async: true
  alias GenesisPubSub.SchemaSpec

  describe "schema spec creation" do
    test "json/0 creates a json based schema spec" do
      assert %SchemaSpec{type: :json, properties: %{}} = SchemaSpec.json()
    end

    test "proto/1 creates a proto based schema spec" do
      # Jason is obviously not a protobuff schema
      # but it does have the same encode/decode behaviour so it works
      assert %SchemaSpec{type: :proto, properties: %{encoder: Jason}} = SchemaSpec.proto(Jason)
    end
  end

  describe "encode!/2" do
    test "json type schema spec" do
      payload = %{name: "Bob", account_id: "123"}
      schema_spec = SchemaSpec.json()

      expected = Jason.encode!(payload)
      assert ^expected = SchemaSpec.encode!(schema_spec, payload)
    end

    test "proto based schema spec" do
      schema_spec = SchemaSpec.proto(TestProto)

      proto = TestProto.new(account_id: "456", name: "Bot")

      expected = TestProto.encode(proto)
      assert ^expected = SchemaSpec.encode!(schema_spec, proto)
    end

    test "json parsing errors are thrown" do
      schema_spec = SchemaSpec.json()

      assert_raise Jason.EncodeError, fn ->
        SchemaSpec.encode!(schema_spec, "\xFF")
      end
    end

    test "proto parsing errors are thrown" do
      schema_spec = SchemaSpec.proto(TestProto)
      # build an invalid proto
      invalid_proto = TestProto.new(account_id: 1, name: 2)

      assert_raise Protobuf.EncodeError, fn -> SchemaSpec.encode!(schema_spec, invalid_proto) end
    end
  end

  describe "encode/2" do
    test "json type schema spec" do
      payload = %{name: "Bob", account_id: "123"}
      schema_spec = SchemaSpec.json()

      expected = Jason.encode(payload)
      assert ^expected = SchemaSpec.encode(schema_spec, payload)
    end

    test "proto based schema spec" do
      schema_spec = SchemaSpec.proto(TestProto)

      proto = TestProto.new(account_id: "123", name: "Alice")
      expected = TestProto.encode(proto)
      assert {:ok, ^expected} = SchemaSpec.encode(schema_spec, proto)
    end

    test "json parsing errors are returned" do
      schema_spec = SchemaSpec.json()

      assert({:error, %Jason.EncodeError{}} = SchemaSpec.encode(schema_spec, "\xFF"))
    end

    test "proto parsing errors are thrown" do
      schema_spec = SchemaSpec.proto(TestProto)
      # build an invalid proto
      invalid_proto = TestProto.new(account_id: 1, name: 2)

      assert {:error, %Protobuf.EncodeError{}} = SchemaSpec.encode(schema_spec, invalid_proto)
    end
  end

  describe "decode/1" do
    test "decoding json payloads" do
      json_spec = SchemaSpec.json()

      payload = %{account_id: "123"}

      assert {:ok, %{"account_id" => "123"}} = SchemaSpec.decode(json_spec, Jason.encode!(payload))
    end

    test "decoding proto payloads" do
      proto_spec = SchemaSpec.proto(TestProto)

      payload = TestProto.new(account_id: "123", name: "Bob")

      assert {:ok, %TestProto{account_id: "123", name: "Bob"}} =
               SchemaSpec.decode(proto_spec, TestProto.encode(payload))
    end
  end
end
