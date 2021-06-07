defmodule Exgencode.Validator do
  @moduledoc """
  Helper functions for field validation
  """

  def validate_field(pdu_name, field_name, props, all_fields) do
    validate_custom_encode_decode(pdu_name, field_name, props, all_fields)
    validate_conditional(pdu_name, field_name, props, all_fields)
    validate_offsets(pdu_name, field_name, props, all_fields)
    validate_field_size(pdu_name, field_name, props, all_fields)
  end

  defp validate_custom_encode_decode(pdu_name, field_name, props, _all_fields) do
    case {props[:encode], props[:decode]} do
      {nil, nil} ->
        :ok

      {_encode_fun, nil} ->
        raise_argument_error(
          pdu_name,
          field_name,
          "Cannot define custom encode without custom decode"
        )

      {nil, _decode_fun} ->
        raise_argument_error(
          pdu_name,
          field_name,
          "Cannot define custom decode without custom encode"
        )

      {_, _} ->
        :ok
    end
  end

  defp validate_conditional(pdu_name, field_name, props, all_fields) do
    case props[:conditional] do
      nil ->
        :ok

      _field ->
        if props[:conditional] not in all_fields,
          do:
            raise_argument_error(
              pdu_name,
              field_name,
              "Invalid conditional reference to nonexistant field"
            )

        if not is_nil(props[:default]) and props[:type] != :subrecord and
             props[:conditional] == nil,
           do:
             raise_argument_error(
               pdu_name,
               field_name,
               "Conditional fields must default to nil!"
             )

        :ok
    end
  end

  defp validate_offsets(pdu_name, field_name, props, all_fields) do
    case props[:offset_to] do
      nil ->
        :ok

      _field ->
        if props[:offset_to] not in all_fields,
          do:
            raise_argument_error(
              pdu_name,
              field_name,
              "Invalid offset reference to nonexistant field"
            )

        if props[:type] != :integer,
          do:
            raise_argument_error(
              pdu_name,
              field_name,
              "Offset fields cannot define types!"
            )

        :ok
    end
  end

  defp validate_field_size(pdu_name, field_name, props, all_fields) do
    size = props[:size]
    encode = props[:encode]
    size_field_in_fields = size in all_fields

    case props[:type] do
      :variable when not size_field_in_fields ->
        raise_argument_error(
          pdu_name,
          field_name,
          "Invalid variable size field reference to nonexistant field"
        )

      :float when size not in [32, 64] ->
        raise_argument_error(
          pdu_name,
          field_name,
          "Invalid size for a :float type field. :float type fields can only be size 32 or 64"
        )

      :subrecord ->
        :ok

      :virtual ->
        :ok

      _ when size == nil and encode == nil ->
        raise_argument_error(
          pdu_name,
          field_name,
          "Field must define field size!"
        )

      _ ->
        :ok
    end
  end

  def validate_pdu(pdu_name, fields) do
    total_size =
      fields
      |> Enum.reject(fn {_field_name, props} -> props[:type] == :variable end)
      |> Enum.map(fn {_field_name, props} ->
        props[:size]
      end)
      |> Enum.filter(&(not is_nil(&1)))
      |> Enum.sum()

    if rem(total_size, 8) != 0,
      do:
        raise(
          ArgumentError,
          "#{inspect(pdu_name |> Macro.to_string())} Total size of PDU must be divisible into full bytes!"
        )
  end

  defp raise_argument_error(pdu_name, field_name, msg) do
    raise ArgumentError,
          "Badly defined field #{inspect(field_name)} in #{inspect(pdu_name |> Macro.to_string())} - " <>
            msg
  end
end
