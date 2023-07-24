# PubSub

A Message and event utility library for pub/sub systems.

## Documentation
> TODO: need to rename and republish pacakge
> In the meantime see docs by running `mix docs` and opening `doc/index.html` in browser

## Installation

> TODO: update name once package is published

```elixir
def deps do
  [
    {:pubsub, "~> 0.11.0"}
  ]
end
```

## Development

### Protobuf

For testing purposes a protobuf definition has been added to this repo at `/lib/pubsub/account_opened.proto`.
If it needs to be regenerated then make sure to follow the installation instructions in the [elixir-protobuf](https://github.com/elixir-protobuf/protobuf) repo for how to install protoc and the elixir plugin (see usage section). With the dependencies in place the following command can be ran to create the protobuf module.

```sh
protoc --elixir_out=./ test/support/*.proto
```
