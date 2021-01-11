defmodule GenesisPubSub.Message do
  @moduledoc """
  Messages are packages of data that transmit between contexts.  They typically
  represent business events that have occured and allow other contexts to react
  to them. Messages rarely happen in isolation. Often a message in one part of
  the system causes another context to take action and produce new events. In
  fully asynchronous systems using pubsub this can go on for days or even weeks
  as different services process messages according to their own schedule.

  Messages are broken into two fields: `data` and `metadata`. `data` is unique to
  the event. It contains pertinent information to the business process that
  created it. This field also supports structured schemas. See:
  `GenesisPubSub.SchemaSpec`.

  `metadata` on the other hand is much more mechanical and informational. It
  helps support showing the connectedness and context around a message. Reading
  from `metadata` is allowed but it is very rare to have to write to the metadata
  field. Many of the functions in `Message` are designed to make handling of
  metadata between two messages automatically. 

  Instead of modifying or creating the struct directly, use the 
  `GenesisPubSub.Message.new/1` or `GenesisPubSub.Message.follow/2` functions
  based on your use case.

  ## Message workflows

  Developers working with messages should mostly focus on the `data` field of a 
  message. This is where all the business use case information goes, and is
  unique to each event. That said, its worth understanding what the metadata
  fields are accomplishing.

  As an example, lets put together a workflow of a few contexts. Imagine we have
  an accounts context that sends account created events, a sales context that
  assigns a rep, and a marketing context that sends welcome emails once a rep has
  been assigned.

  ### Account context

  The Account context is the first action in the chain. Maybe a web form supplies
  information that causes this workflow to kick off. Since they are the first
  event and not respondig to a previous event they use
  `GenesisPubSub.Message.new/1`

      account_opened = Messages.new(data: %{account_id: "123", first_name: "Bob"})
      GenesisPubSub.Producer.publish(AccountOpenedProducer, account_opened)

  ### Sales Context

  When new accounts are created the sales context kicks in and assigns a rep.
  Since we are responding to a previous event we should leverage
  `GenesisPubSub.Message.follow/2` to correlate the two events.

      def assign_rep(%Message{data: %{account_id: id}, metadata: %{topic: "account-opened"}}) do
        # do work of assigning rep
        # ...

        rep_assigned = account_opened
        |> Message.follow(include: [:account_id, :first_name])
        # add additional fields
        |> Message.put(:rep_name, "Tony Robbins")

        GenesisPubSub.Producer.publish(RepAssignedProducer, rep_assigned)
      end

  ### Marketing Context

  In marketing once a sales rep has been assigned to new accounts we send a
  welcome email, again correlating to the previous event from the sales context.

      def send_welcome_email(%Message{data: data, metadata: %{topic: "rep-assigned"}} = rep_assigned) do
        :ok = Marketing.Email.welcome_email(%{account: data["account_id"], rep: data["rep_name"]})

        welcome_email_sent = Message.follow(rep_assigned, exclude: [])

        GenesisPubSub.Producer.publish(WelcomeEmailProducer, send_welcome_email)
      end

  ### Outcome

  By properly creating messages a chain of events is created. The very first
  message, `account-opened` would have a `causation_id` of `nil`. This makes it
  the first event. Every following message's `causation_id` would be the
  `event_id` of the message it followed. Lastly they would all have the same
  `correlation_id`.

  What this means in the end is that given a `correlation_id` you could get all
  of the events that happened within it and put them in the right order by using
  the `causation_id`. This becomes super useful when looking into workflows that
  span over any amount of time.
  """

  alias GenesisPubSub.Message.Metadata
  alias GenesisPubSub.SchemaSpec

  @enforce_keys [:data, :metadata]
  defstruct [:data, :metadata]

  @typedoc """
  Once a message has been published details such as its id and publish time are
  made available.
  """
  @type published_t :: %__MODULE__{
          data: any(),
          metadata: Metadata.published_t()
        }

  @typedoc """
  Before a message has been published certain metadata is not yet available.
  """
  @type unpublished_t :: %__MODULE__{
          data: any(),
          metadata: Metadata.unpublished_t()
        }

  @typedoc """
  A `GenesisPubSub.SchemaSpec` can be used to encode a message to prepare it to
  be sent through an adapter.
  """
  @type serialized_t :: %{data: String.t(), metadata: map()}

  @doc """
  Creates a new `Message`.

  Options:

  * `data` - map of data to seed message with

  * `metadata` - map of metadata to merge into generated metadata

  Examples:

  Passing initial data for message.

      iex> message = GenesisPubSub.Message.new(data: %{account_id: "123"})
      iex> message.data
      %{account_id: "123"}

  Scaffolding out an empty message

      iex> message = GenesisPubSub.Message.new()
      iex> message.data
      %{}
  """
  def new(opts \\ []) do
    %__MODULE__{
      data: Keyword.get(opts, :data, %{}),
      metadata: Metadata.new(Keyword.get(opts, :metadata, %{}))
    }
  end

  @doc """
  Creates a new `Message` by "following" a previous one. See "Message Workflows"
  for full explanation.

  Following has the benefit of linking the metadata between two events,
  correlating them to each other. Following is the preferred way of creating new
  messages when they are the response to a previous message.

  Options:

  * `include` - list of fields to copy over into new events data
    If the previous message contains values the new event needs then this can be
    used to seed the new events data.

  * `exclude` - list of fields to exlude from copying over into new events data
    All other fileds will be copied over to new event. This option takes
    precedence over `include`.

  Examples:

      iex> message = Message.new(data: %{account_id: "1"})
      iex> next_message = Message.follow(message, include: [:account_id])
      iex> next_message.data
      %{account_id: "1"}

      iex> message = Message.new(data: %{account_id: "1", name: "Bob"})
      iex> next_message = Message.follow(message, exclude: [:name])
      iex> next_message.data
      %{account_id: "1"}

  It's also worthwhile to copy over any fields from the original message into the
  new message even just to use the new message as a temporary argument storage.
  Consider the following example.

      previous_message = Message.new(data: %{account_id: "123"})
      message = Message.follow(previous_message, include: [:account_id])
      message = Message.put(message, :first_name, "Bob")
      message = Message.update_data(message, fn data -> struct!(Account, data) end)
  """
  def follow(%__MODULE__{} = previous_message, opts \\ []) do
    %__MODULE__{
      data: copy(previous_message.data, opts),
      metadata: Metadata.follow(previous_message.metadata)
    }
  end

  @doc """
  Updates data field of `message`.

  Second argument can either be a function that will receive the current data and
  will update whatever is returned. Or it can be a new value to put in place of 
  old data

      iex> message = Message.new(data: %{account_id: "123"})
      iex> message = Message.update_data(message, fn data -> Map.put(data, :key, "value") end)
      iex> message.data
      %{account_id: "123", key: "value"}

      iex> message = Message.new(data: %{account_id: "123"})
      iex> message = Message.update_data(message, %{first_name: "Bob"})
      iex> message.data
      %{first_name: "Bob"}

  """
  def update_data(%__MODULE__{} = message, updater) when is_function(updater) do
    new_data = updater.(message.data)
    update_data(message, new_data)
  end

  def update_data(%__MODULE__{} = message, new_data) do
    %__MODULE__{
      message
      | data: new_data
    }
  end

  @doc """
  Put `value` at `key` in `message` data field.

      iex> message = Message.new()
      iex> message = Message.put(message, :account_id, "123")
      iex> message.data
      %{account_id: "123"}
  """
  def put(%__MODULE__{} = message, key, value) do
    %__MODULE__{
      message
      | data: Map.put(message.data, key, value)
    }
  end

  @doc """
  Merge `map` into `message` data field. Existing keys will be replaced by `map`
  key.

      iex> message = Message.new(data: %{account_id: "123"})
      iex> message = Message.merge(message, %{account_id: "456", first_name: "Bob"})
      iex> message.data
      %{account_id: "456", first_name: "Bob"}
  """
  def merge(%__MODULE__{} = message, map) when is_map(map) do
    %__MODULE__{
      message
      | data: Map.merge(message.data, map)
    }
  end

  @doc """
  Puts `value` at `key` in `message` metadata field.

  This function is reserved for internal use to decorate metadata with
  derived information. Only call this function if you know what you are
  doing.

        iex> message = Message.new()
        iex> message = Message.put_meta(message, :event_id, "123")
        iex> message.metadata.event_id
        "123"
  """
  def put_meta(%__MODULE__{metadata: meta} = message, key, value) do
    %__MODULE__{
      message
      | metadata: Map.put(meta, key, value)
    }
  end

  @spec encode(unpublished_t() | published_t()) ::
          {:ok, serialized_t()}
          | {:error, :missing_schema_spec}
          | {:error, json_codec_error :: any()}
  @doc """
  Encodes a `message` data and metadata into a serializable format.
  """
  def encode(%__MODULE__{data: data, metadata: %Metadata{schema: %SchemaSpec{} = spec} = meta}) do
    with {:ok, encoded_payload} <- SchemaSpec.encode(spec, data),
         encoded_meta <- Metadata.to_encodable(meta) do
      {:ok, %{data: encoded_payload, metadata: encoded_meta}}
    end
  end

  def encode(%__MODULE__{}) do
    {:error, :missing_schema_spec}
  end

  # helper for copying over values based on options
  defp copy(previous_message_data, opts) do
    exclude = Keyword.get(opts, :exclude)
    include = Keyword.get(opts, :include)

    cond do
      exclude != nil ->
        # drop exclude keys from previous message
        exclude
        |> Enum.reduce(previous_message_data, fn exclude_key, params ->
          Map.delete(params, exclude_key)
        end)

      include != nil ->
        # take include keys from previous message
        Map.take(previous_message_data, include)

      true ->
        %{}
    end
  end
end
