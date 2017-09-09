# Exgencode
[![Build Status](https://travis-ci.org/haljin/exgencode.svg?branch=master)](https://travis-ci.org/haljin/exgencode) [![Hex.pm Version](http://img.shields.io/hexpm/v/exgencode.svg?style=flat)](https://hex.pm/packages/exgencode)

## Description

This package allows for simple definition of binary-based protocols together with an Elixir protocol that allows for
simple transforming of binary packages into Elixir structures and vice versa.

The protocols are defined by creating a module for each protocole and utilising the PDU definitions to define all
messages the protocol needs. See the following sections for more.

## Installation

The package is [available in Hex](https://hex.pm/docs/publish) and can be installed
by adding `exgencode` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exgencode, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc). 
The documentation can also be found at [https://hexdocs.pm/exgencode](https://hexdocs.pm/exgencode).

## Usage

Protocol messages can be defined using the `defpdu` macro. Each message is defined with its name and a list of message fields 
and their options. Each field should define the size (given in bits) for the particular and can define a default value. For example:

```elixir
defpdu ExamplePdu, 
  firstField: [size: 10],
  fieldWithADefault: [size: 12, default: 5]
```

Once defined the code can use the messages as structure e.g. `%ExamplePdu{firstField: 5}`

Messages can also be nested within other messages. In that case the field must by of type `:subrecord` and must define the default
which indicates which what type of sub-structure should the field contain.

```elixir
defpdu SubPdu,
  someField: [size: 8, default: 1]

defpdu MainPdu,
  section: [size: 16]
  subSection: [type: :subrecord, default: %SubPdu{}]
```

Alternatively each field may define custom encoding and decoding functions:

```elixir
defpdu CustomPdu,
  normalField: [size: 16, default: 3]
  customField: [encode: fn(val) -> << val :: size(12) >> end,
                decode: fn(pdu, << val :: size(12) >>) -> {struct(pdu, :customField => val), <<>>} end]

```

With custom functions other parameters can be omitted.

It is reccommended to place all messages for a given interface in one module.

```elixir
defmodule MyProtocol do
  defpdu HelloMsg,
    userId: [size: 256]

  defpdu ByeMsg,
    userId: [size: 256]
end
```

### Pdu Protocol

`exgencode` also provides the `Exgencode.Pdu` protocol that each pdu defined with `defpdu` will automatically implement. This protocol can be used
to transform between binary and structures.

```elixir
defpdu MsgSubSection,
    someField: [default: 15, size: 8]

defpdu PzTestMsg, 
  testField: [default: 1, size: 12], 
  otherTestField: [size: 24],
  subSection: [default: %MsgSubSection{}, type: :subrecord],
  constField: [default: 10, size: 24, type: :constant]

test "encoding" do
  pdu = %TestPdu.PzTestMsg{otherTestField: 100}
  assert << 1 :: size(12), 100 :: size(24), 15 :: size(8), 10 :: size(24)>> == Exgencode.Pdu.encode(pdu)
end

test "decoding" do
  pdu = %TestPdu.PzTestMsg{otherTestField: 100}
  binary = << 1 :: size(12), 100 :: size(24), 15 :: size(8), 10 :: size(24)>>
  assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.PzTestMsg{}, binary)
end
```

See the [documentation](https://hexdocs.pm/exgencode) for details.

