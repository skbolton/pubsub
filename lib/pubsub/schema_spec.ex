defmodule GenesisPubSub.SchemaSpec do
  @moduledoc """
  Module for defining schema specifications to support encoding/decoding.

  Producers can publish messages serialized into any supported formats. To enable
  Consumers to be able to consume messages a schema spec is used to define how to
  decode a given message. SchemaSpecs are encoded into a Message's Metadata.
  """
  defstruct [:type, :properties]

  @type type :: :json | :proto

  @type t ::
          %__MODULE__{
            type: type(),
            properties: map()
          }

  @doc """
  Creates `SchemaSpec` for `:json` encoded messages.
  """
  def json() do
    %__MODULE__{
      type: :json,
      properties: %{}
    }
  end

  @doc """
  Creates `SchemaSpec` for `:proto` encoded messages, using `encoder` as the
  module to encode/decode the message payload.
  """
  def proto(encoder) when is_atom(encoder) do
    %__MODULE__{
      type: :proto,
      properties: %{
        encoder: encoder
      }
    }
  end

  def encode(%__MODULE__{type: :json}, message) do
    GenesisPubSub.json_codec().encode(message)
  end

  def encode(%__MODULE__{type: :proto, properties: %{encoder: encoder}}, message) do
    # protobuf elixir decided to have their encode/1 work like Jason.encode!/1
    # so we have to catch errors to keep the same contract
    {:ok, encoder.encode(message)}
  rescue
    e ->
      {:error, e}
  end

  def encode!(%__MODULE__{type: :json}, message) do
    GenesisPubSub.json_codec().encode!(message)
  end

  def encode!(%__MODULE__{type: :proto, properties: %{encoder: encoder}}, message) do
    encoder.encode(message)
  end

  def decode(%__MODULE__{type: :json}, payload) do
    GenesisPubSub.json_codec().decode(payload)
  end

  def decode(%__MODULE__{type: :proto, properties: %{encoder: encoder}}, payload) do
    # protobuf elixir decided to have their decode/1 work like Jason.decode!/1
    # so we have to catch errors to keep the same contract
    {:ok, encoder.decode(payload)}
  catch
    e ->
      {:error, e}
  end
end
