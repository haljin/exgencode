defmodule Exgencode.Sizeof do
  @moduledoc """
  Helper functions for generating `sizeof/2` protocol function implementation.
  """

  def build_sizeof(field_list) do
    field_list
    |> Enum.map(fn {name, props} ->
      case props[:type] do
        :variable ->
          size_field = props[:size]

          {name,
           quote do
             (fn p -> Map.get(p, unquote(size_field)) end).(pdu) * 8
           end}

        :virtual ->
          {name, 0}

        :subrecord ->
          {name, {:subrecord, props[:default]}}

        _ ->
          {name, props[:size]}
      end
    end)
    |> Enum.map(fn {name, size} ->
      quote do
        def sizeof(pdu, unquote(name)), do: unquote(size)
      end
    end)
  end

  def build_sizeof_pdu(field_list) do
    names = Enum.map(field_list, fn {name, props} -> {name, props[:version]} end)

    quote do
      def sizeof_pdu(pdu, nil, type) do
        do_size_of_pdu(pdu, unquote(names), nil, type)
      end

      def sizeof_pdu(pdu, version, type) do
        fields =
          Enum.filter(
            unquote(names),
            fn {_, field_version} ->
              field_version == nil || Version.match?(version, field_version)
            end
          )

        do_size_of_pdu(pdu, fields, version, type)
      end

      defp do_size_of_pdu(pdu, fields, version, type) do
        fields
        |> Enum.map(fn {field_name, props} ->
          case Exgencode.Pdu.sizeof(pdu, field_name) do
            {:subrecord, record} ->
              Exgencode.Pdu.sizeof_pdu(record, version)

            val ->
              val
          end
        end)
        |> Enum.sum()
        |> bits_or_bytes(type)
      end

      defp bits_or_bytes(sum, :bits), do: sum
      defp bits_or_bytes(sum, :bytes), do: div(sum, 8)
    end
  end
end
