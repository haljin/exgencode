defmodule Exgencode do
  @moduledoc """
  Documentation for Exgencode.
  """

  defprotocol Pdu do
    def sizeof(pdu, fieldName)
    def encode(pdu)
    def decode(pdu, binary)
  end



  defmacro defpdu name, originalFieldList do
    fieldList = for {fieldName, props} <- originalFieldList do
      case {props[:encode], props[:decode]} do
        {nil, nil} -> 
          customEncodeFun = 
          case props[:size] do
            :subrecord -> 
              quote do fn(fieldVal) -> << Exgencode.Pdu.encode(fieldVal) :: bitstring >> end end
            fieldSize when is_integer(fieldSize) ->
              case props[:constant] do
                nil -> quote do fn(fieldVal) -> << fieldVal :: size(unquote(fieldSize))>> end end
                true -> quote do fn(_) -> << unquote(props)[:default] :: size(unquote(fieldSize)) >> end end
              end
          end  
          customDecodeFun = 
          case props[:size] do
            :subrecord -> 
              quote do fn(pdu, binary) -> 
                {fieldValue, restBinary} = Exgencode.Pdu.decode(unquote(props)[:default], binary)
                {Map.replace(pdu, unquote(fieldName), fieldValue), restBinary}  end end
            fieldSize when is_integer(fieldSize) ->
              quote do fn(pdu, << fieldValue :: size(unquote(fieldSize)), restBinary :: bitstring >>) -> {Map.replace(pdu, unquote(fieldName), fieldValue), restBinary} end end
          end         
          {fieldName, [{:encode, customEncodeFun}, {:decode, customDecodeFun} | props]}
        {_encodeFun, nil} -> 
          raise ArgumentError, "Cannot define custom encode without custom decode"
        {nil, _decodeFun} ->
          raise ArgumentError, "Cannot define custom decode without custom encode"
        _ ->
          {fieldName, props}
      end
    end

    quote do
      defmodule unquote(name) do
        fields = for {fieldName, props} <- unquote(fieldList), props[:constant] == nil do {fieldName, props[:default]} end
        defstruct fields
      end

      defimpl Exgencode.Pdu, for: unquote(name) do
        def sizeof(pdu, fieldName) do
          unquote(fieldList)[fieldName][:size]          
        end

        def encode(pdu) do
          for {field, props} <- unquote(fieldList), into: <<>> do
            props[:encode].(Map.get(pdu, field))
          end
        end

        def decode(pdu, binary) do      
          do_decode(pdu, binary, unquote(fieldList))
        end

        defp do_decode(pdu, binary, [{field, props} | rest]) do
          {newPdu, restBinary} = props[:decode].(pdu, binary)
          do_decode(newPdu, restBinary, rest)
        end
        defp do_decode(pdu, restBin, []) do
          {pdu, restBin}
        end
      end
    end    
  end

end
