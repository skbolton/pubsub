# PubSub

A Message and event utility library for pub/sub systems.

## Installation

```bash
mix hex.organization auth genesisblock --key <'Private Hex Key' from 1password>
```

```elixir
def deps do
  [
    {:genesis_pubsub, "~> 0.8.7", organization: "genesisblock"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://genesisblock.hexdocs.pm/genesis_pubsub](https://genesisblock.hexdocs.pm/genesis_pubsub).

## Development

### Protobuf

For testing purposes a protobuf definition has been added to this repo at `/lib/pubsub/account_opened.proto`. If it needs to be regenerated then make sure to follow the installation instructions in the [elixir-protobuf](https://github.com/elixir-protobuf/protobuf) repo for how to install protoc and the elixir plugin (see usage section). With the dependencies in place the following command can be ran to create the protobuf module.

```sh
$ protoc --elixir-out=./ ./lib/pubsub/*.proto
```
