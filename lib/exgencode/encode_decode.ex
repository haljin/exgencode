defmodule Exgencode.EncodeDecode do
  @moduledoc """
  Helper functions for generating encoding and decoding functions.
  """

  def create_versioned_encode(function, nil, :subrecord) do
    quote do: fn version -> unquote(function) end
  end

  def create_versioned_encode(function, nil, _) do
    quote do: fn _ -> unquote(function) end
  end

  def create_versioned_encode(function, version, _) do
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

  def create_versioned_decode(function, nil, :subrecord) do
    quote do: fn version -> unquote(function) end
  end

  def create_versioned_decode(function, nil, _) do
    quote do: fn _ -> unquote(function) end
  end

  def create_versioned_decode(function, version, _) do
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

  def create_encode_fun(:subrecord, field_name, props) do
    basic_fun =
      quote do: fn %{unquote(field_name) => field_val} ->
              <<Exgencode.Pdu.encode(field_val, version)::bitstring>>
            end

    wrap_conditional_encode(props, basic_fun)
  end

  def create_encode_fun(:virtual, _field_name, _props) do
    quote do: fn _ -> <<>> end
  end

  def create_encode_fun(:constant, _field_name, props) do
    field_size = props[:size]
    default = props[:default]
    conditional = props[:conditional]
    endianness = props[:endianness]
    field_encode_type = Macro.var(endianness, __MODULE__)

    basic_fun =
      if is_nil(conditional) do
        quote do: fn _ ->
                <<unquote(default)::unquote(field_encode_type)-size(unquote(field_size))>>
              end
      else
        quote do
          fn
            %{unquote(conditional) => field_val}
            when field_val == nil or field_val == 0 or field_val == "" ->
              <<>>

            _ ->
              <<unquote(default)::unquote(field_encode_type)-size(unquote(field_size))>>
          end
        end
      end

    wrap_conditional_encode(props, basic_fun)
  end

  def create_encode_fun(:string, field_name, props) do
    field_size = props[:size]
    endianness = props[:endianness]
    field_endian_type = Macro.var(endianness, __MODULE__)
    field_encode_type = Macro.var(:binary, __MODULE__)

    basic_fun =
      quote do
        fn %{unquote(field_name) => field_val} ->
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

    wrap_conditional_encode(props, basic_fun)
  end

  def create_encode_fun(sized_type, field_name, props)
      when sized_type == :integer
      when sized_type == :float
      when sized_type == :binary do
    field_size = props[:size]
    endianness = props[:endianness]
    field_endian_type = Macro.var(endianness, __MODULE__)
    field_encode_type = Macro.var(sized_type, __MODULE__)

    basic_fun =
      quote do: fn %{unquote(field_name) => field_val} ->
              <<field_val::unquote(field_endian_type)-unquote(field_encode_type)-size(
                  unquote(field_size)
                )>>
            end

    wrap_conditional_encode(props, basic_fun)
  end

  def create_encode_fun(:variable, field_name, props) do
    field_size = props[:size]
    endianness = props[:endianness]
    field_endian_type = Macro.var(endianness, __MODULE__)
    field_encode_type = Macro.var(:binary, __MODULE__)

    basic_fun =
      quote do: fn %{unquote(field_name) => field_val, unquote(field_size) => size_val} ->
              <<field_val::unquote(field_endian_type)-unquote(field_encode_type)-size(size_val)>>
            end

    wrap_conditional_encode(props, basic_fun)
  end

  def create_encode_fun(:skip, _field_name, props) do
    field_size = props[:size]
    default = props[:default]
    endianness = props[:endianness]
    field_encode_type = Macro.var(endianness, __MODULE__)

    basic_fun =
      quote do: fn _ ->
              <<unquote(default)::unquote(field_encode_type)-size(unquote(field_size))>>
            end

    wrap_conditional_encode(props, basic_fun)
  end

  defp wrap_conditional_encode(props, basic_fun) do
    case props[:conditional] do
      nil ->
        basic_fun

      conditional_field_name ->
        quote do: fn
                %{unquote(conditional_field_name) => val}
                when val == 0 or val == "" or val == nil ->
                  <<>>

                p ->
                  unquote(basic_fun).(p)
              end
    end
  end

  def create_decode_fun(:subrecord, field_name, props) do
    default = props[:default]

    basic_fun =
      quote do
        fn pdu, binary ->
          {field_value, rest_binary} = Exgencode.Pdu.decode(unquote(default), binary, version)
          {struct!(pdu, %{unquote(field_name) => field_value}), rest_binary}
        end
      end

    wrap_conditional_decode(props, basic_fun)
  end

  def create_decode_fun(:virtual, field_name, props) do
    default = props[:default]

    quote do
      fn pdu, rest_binary ->
        {struct!(pdu, %{unquote(field_name) => unquote(default)}), rest_binary}
      end
    end
  end

  def create_decode_fun(:constant, _field_name, props) do
    default = props[:default]
    field_size = props[:size]
    endianness = props[:endianness]
    field_encode_type = Macro.var(endianness, __MODULE__)

    basic_fun =
      quote do: fn pdu,
                   <<unquote(default)::unquote(field_encode_type)-size(unquote(field_size)),
                     rest_binary::bitstring>> ->
              {pdu, rest_binary}
            end

    wrap_conditional_decode(props, basic_fun)
  end

  def create_decode_fun(:string, field_name, props) do
    field_size = props[:size]
    endianness = props[:endianness]
    field_endian_type = Macro.var(endianness, __MODULE__)
    field_encode_type = Macro.var(:binary, __MODULE__)

    basic_fun =
      quote do
        fn pdu,
           <<field_value::unquote(field_endian_type)-unquote(field_encode_type)-size(
               unquote(field_size)
             ), rest_binary::bitstring>> ->
          {struct!(pdu, %{unquote(field_name) => String.trim_trailing(field_value, <<0>>)}),
           rest_binary}
        end
      end

    wrap_conditional_decode(props, basic_fun)
  end

  def create_decode_fun(sized_type, field_name, props)
      when sized_type == :integer
      when sized_type == :float
      when sized_type == :binary do
    field_size = props[:size]
    endianness = props[:endianness]
    field_endian_type = Macro.var(endianness, __MODULE__)
    field_encode_type = Macro.var(sized_type, __MODULE__)

    basic_fun =
      quote do
        fn pdu,
           <<field_value::unquote(field_endian_type)-unquote(field_encode_type)-size(
               unquote(field_size)
             ), rest_binary::bitstring>> ->
          {struct!(pdu, %{unquote(field_name) => field_value}), rest_binary}
        end
      end

    wrap_conditional_decode(props, basic_fun)
  end

  def create_decode_fun(:variable, field_name, props) do
    field_size = props[:size]
    endianness = props[:endianness]
    field_endian_type = Macro.var(endianness, __MODULE__)
    field_encode_type = Macro.var(:binary, __MODULE__)

    basic_fun =
      quote do
        fn %{unquote(field_size) => size_val} = pdu, bin ->
          <<field_value::unquote(field_endian_type)-unquote(field_encode_type)-size(size_val),
            rest_binary::bitstring>> = bin

          {struct!(pdu, %{unquote(field_name) => field_value}), rest_binary}
        end
      end

    wrap_conditional_decode(props, basic_fun)
  end

  def create_decode_fun(:skip, _field_name, props) do
    field_size = props[:size]
    endianness = props[:endianness]
    field_encode_type = Macro.var(endianness, __MODULE__)

    basic_fun =
      quote do: fn pdu,
                   <<_::unquote(field_encode_type)-size(unquote(field_size)),
                     rest_binary::bitstring>> ->
              {pdu, rest_binary}
            end

    wrap_conditional_decode(props, basic_fun)
  end

  def skip_to_offset(pdu, field, rest_binary, pdu_bit_size, offset_targets) do
    case offset_targets do
      %{^field => offset_field} ->
        do_skip_to_offset(pdu, field, offset_field, rest_binary, pdu_bit_size)

      _ ->
        rest_binary
    end
  end

  defp do_skip_to_offset(pdu, field, offset_field, rest_binary, pdu_bit_size) do
    case Map.get(pdu, offset_field) do
      offset when offset in [0, nil] ->
        rest_binary

      offset ->
        cursor = pdu_bit_size - bit_size(rest_binary)
        target = offset * 8

        cond do
          target == cursor ->
            rest_binary

          target < cursor ->
            raise Exgencode.DecodeError,
                  "offset field #{inspect(offset_field)} of #{inspect(field)} cannot point backwards!"

          target > pdu_bit_size ->
            raise Exgencode.DecodeError,
                  "offset_field #{inspect(offset_field)} cannot point outside binary!"

          true ->
            gap_bits = target - cursor
            <<_padding::size(gap_bits), rest::bitstring>> = rest_binary
            rest
        end
    end
  end

  def wrap_custom_encode(field_name, encode_fun) do
    quote do
      fn pdu ->
        unquote(encode_fun).(Map.get(pdu, unquote(field_name)))
      end
    end
  end

  defp wrap_conditional_decode(props, basic_fun) do
    case props[:conditional] do
      nil ->
        basic_fun

      conditional_field_name ->
        quote do
          fn
            %{unquote(conditional_field_name) => val} = pdu, binary
            when val == 0 or val == "" or val == nil ->
              {pdu, binary}

            pdu, binary ->
              unquote(basic_fun).(pdu, binary)
          end
        end
    end
  end
end
