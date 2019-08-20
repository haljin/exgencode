defmodule Exgencode.Offsets do
  @moduledoc """
  Helper functions for generating offset calculating functions.
  """

  def create_offset_fun(field_list) do
    offset_field_funs =
      field_list
      |> Enum.filter(fn {_, props} ->
        case props[:offset_to] do
          nil -> false
          _ -> true
        end
      end)
      |> Enum.map(fn {name, props} ->
        create_offset_fun(name, props, field_list)
      end)

    case offset_field_funs do
      [] ->
        quote do
          def set_offsets(pdu, _version), do: pdu
        end

      field_funs ->
        quote do
          def set_offsets(pdu, version) do
            unquote(field_funs)
            |> Enum.reduce({pdu, version}, fn fun, {pdu, version} ->
              fun.(pdu, version)
            end)
            |> elem(0)
          end
        end
    end
  end

  def create_offset_fun(field_name, props, field_list) do
    other_field = props[:offset_to]

    fields_to_offset =
      field_list
      |> Enum.take_while(fn
        {^other_field, _} -> false
        _ -> true
      end)
      |> Enum.map(fn {name, props} -> {name, props[:version]} end)

    quote do: fn
            %{unquote(other_field) => nil} = pdu, version ->
              {struct!(pdu, %{unquote(field_name) => 0}), version}

            pdu, version ->
              val =
                unquote(fields_to_offset)
                |> Enum.filter(fn {_, ver} ->
                  is_nil(version) or is_nil(ver) or Version.match?(version, ver)
                end)
                |> Enum.map(fn {n, _} -> n end)
                |> Enum.map(&Exgencode.Pdu.sizeof(pdu, &1))
                |> Enum.map(fn
                  {:subrecord, record} -> Exgencode.Pdu.sizeof_pdu(record, version, :bytes)
                  val -> div(val, 8)
                end)
                |> Enum.sum()

              {struct!(pdu, %{unquote(field_name) => val}), version}
          end
  end
end
