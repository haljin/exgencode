defmodule Exgencode.EncodeDecode do
  @moduledoc """
  Helper functions for generating encoding and decoding functions.
  """

  def create_versioned_encode(function, nil) do
    quote do: fn _ -> unquote(function) end
  end

  def create_versioned_encode(function, version) do
    quote do
      fn
        nil ->
          unquote(function)

        ver ->
          if Version.match?(ver, unquote(version)) do
            unquote(function)
          else
            fn _ -> <<>> end
          end
      end
    end
  end

  def create_versioned_decode(function, nil) do
    quote do: fn _ -> unquote(function) end
  end

  def create_versioned_decode(function, version) do
    quote do
      fn
        nil ->
          unquote(function)

        ver ->
          if Version.match?(ver, unquote(version)) do
            unquote(function)
          else
            fn pdu, bin -> {pdu, bin} end
          end
      end
    end
  end

  def create_encode_fun(:subrecord, _field_size, _default, _endianness) do
    quote do: fn field_val -> <<Exgencode.Pdu.encode(field_val)::bitstring>> end
  end

  def create_encode_fun(:virtual, _field_size, _default, _endianness) do
    quote do: fn field_val -> <<>> end
  end

  def create_encode_fun(:constant, field_size, default, endianness) do
    field_encode_type = Macro.var(endianness, __MODULE__)

    quote do: fn _ ->
            <<unquote(default)::unquote(field_encode_type)-size(unquote(field_size))>>
          end
  end

  def create_encode_fun(:string, field_size, _default, endianness) do
    field_endian_type = Macro.var(endianness, __MODULE__)
    field_encode_type = Macro.var(:binary, __MODULE__)

    quote do
      fn field_val ->
        padded_field_val =
          cond do
            byte_size(field_val) == unquote(field_size) ->
              field_val

            byte_size(field_val) > unquote(field_size) ->
              binary_part(field_val, 0, unquote(field_size))

            byte_size(field_val) < unquote(field_size) ->
              field_val <>
                for _ <- 1..(unquote(field_size) - byte_size(field_val)), into: <<>>, do: <<0>>
          end

        <<padded_field_val::unquote(field_endian_type)-unquote(field_encode_type)-size(
            unquote(field_size)
          )>>
      end
    end
  end

  def create_encode_fun(sized_type, field_size, _default, endianness)
      when sized_type == :integer
      when sized_type == :float
      when sized_type == :binary do
    field_endian_type = Macro.var(endianness, __MODULE__)
    field_encode_type = Macro.var(sized_type, __MODULE__)

    quote do: fn field_val ->
            <<field_val::unquote(field_endian_type)-unquote(field_encode_type)-size(
                unquote(field_size)
              )>>
          end
  end

  def create_decode_fun(:subrecord, _field_size, default, field_name, _endianness) do
    quote do
      fn pdu, binary ->
        {field_value, rest_binary} = Exgencode.Pdu.decode(unquote(default), binary)
        {Map.replace!(pdu, unquote(field_name), field_value), rest_binary}
      end
    end
  end

  def create_decode_fun(:virtual, _field_size, default, field_name, _endianness) do
    quote do
      fn pdu, rest_binary ->
        {struct!(pdu, %{unquote(field_name) => unquote(default)}), rest_binary}
      end
    end
  end

  def create_decode_fun(:constant, field_size, default, _field_name, endianness) do
    field_encode_type = Macro.var(endianness, __MODULE__)

    quote do: fn pdu,
                 <<unquote(default)::unquote(field_encode_type)-size(unquote(field_size)),
                   rest_binary::bitstring>> ->
            {pdu, rest_binary}
          end
  end

  def create_decode_fun(:string, field_size, _default, field_name, endianness) do
    field_endian_type = Macro.var(endianness, __MODULE__)
    field_encode_type = Macro.var(:binary, __MODULE__)

    quote do
      fn pdu,
         <<field_value::unquote(field_endian_type)-unquote(field_encode_type)-size(
             unquote(field_size)
           ), rest_binary::bitstring>> ->
        {struct!(pdu, %{unquote(field_name) => String.trim_trailing(field_value, <<0>>)}),
         rest_binary}
      end
    end
  end

  def create_decode_fun(sized_type, field_size, _default, field_name, endianness)
      when sized_type == :integer
      when sized_type == :float
      when sized_type == :binary do
    field_endian_type = Macro.var(endianness, __MODULE__)
    field_encode_type = Macro.var(sized_type, __MODULE__)

    quote do
      fn pdu,
         <<field_value::unquote(field_endian_type)-unquote(field_encode_type)-size(
             unquote(field_size)
           ), rest_binary::bitstring>> ->
        {struct!(pdu, %{unquote(field_name) => field_value}), rest_binary}
      end
    end
  end
end
