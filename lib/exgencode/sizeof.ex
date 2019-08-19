defmodule Exgencode.Sizeof do
  @moduledoc """
  Helper functions for generating `sizeof/2` protocol function implementation.
  """

  def build_sizeof(field_list) do
    field_list
    |> Enum.map(&build_size/1)
    |> Enum.map(&build_conditional/1)
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

  defp build_size({name, props}) do
    case props[:type] do
      :variable ->
        size_field = props[:size]

        {name, props,
         quote do
           (fn %{unquote(size_field) => val} -> val end).(pdu) * 8
         end}

      :virtual ->
        {name, props, 0}

      :subrecord ->
        {name, props, {:subrecord, props[:default]}}

      _ ->
        {name, props, props[:size]}
    end
  end

  defp build_conditional({name, props, size}) do
    case props[:conditional] do
      nil ->
        {name, size}

      conditional_field_name ->
        {name,
         quote do
           (fn
              %{unquote(conditional_field_name) => val} = p
              when val == 0 or val == "" or val == nil ->
                0

              p ->
                unquote(size)
            end).(pdu)
         end}
    end
  end
end
