defmodule Exgencode do
  @moduledoc """
  Documentation for Exgencode.
  """

  defprotocol Pdu do
    def sizeof(pdu, fieldName)
    def encode(pdu)
    def decode(pdu, binary)
  end

  @typedoc "A PDU, that is an Elixir structure representing a PDU."
  @type pdu :: %{}
  @typedoc "PDU name, must be a structure name"
  @type pduName :: module
  @typedoc "The type of the field."
  @type fieldType :: :subrecord | :constant
  @typedoc "A custom encoding function that is meant to take the value of the field and return its binary represantion."
  @type fieldEncodeFun :: ((term) -> bitstring)
  @typedoc "A custom decoding function that receives the PDU decoded so far and remaining binary and is meant to return PDU with the field decoded and remaining binary."
  @type fieldDecodeFun :: ((pdu, bitstring) -> {pdu, bitstring})
  @typedoc "Parameters of the given field"
  @type fieldParam :: {:size, non_neg_integer} | {:type, fieldType} | {:encode, fieldEncodeFun} | {:decode, fieldDecodeFun}
  @typedoc "Name of the field."
  @type fieldName :: atom

  @doc """
  This macro allows for the definition of binary PDUs in a simple way allowing for convienient encoding and decoding them between
  binary format and Elixir structures.

  # PDUs
  Each PDU for the protocol is defined given a name that must be a valid Elixir structure (module) name followed by a list
  of fields that the given PDU has. 

  ## Fields
  Each field can have the following options specified:

  ### size 
  Defines the size of field in bits. If the field is of type :subrecord the :size is unused.
    
      defpdu SomePdu
        someField: [size: 12]

  ### default
  Defines the default value that the field should assume when building a new Elixir structure of the given PDU.

      defpdu PduWithDefault
        aFieldWithDefault: [size: 10, default: 15]

  ### type
  Defines the type of the field. Field can be of :constant or :subrecord types. If the field is meant to be a normal numerical value no type should be specified.
  
  #### :constant
  If the field is constant it will not become part of the Elixir structure and will not be accessible. However it will still be 
  encoded into the binary representation and the decoding will expect the field to be present and have the given value in the decoded binary. Otherwise
  FunctionClauseError will be raised. A :constant field MUST have a default value specified.

      defpdu PduWithConstant,
        aConstantField: [size: 12, default: 10, type: :constant]

  #### :subrecord
  If the field is meant to contain a sub-structure then it should be of type :subrecord. Such field must have either a default value specified that is of the
  type of the subrecord. Alternatively it must define custom decode and encode functions.

      defpdu SubPdu,
        someField: [size: 10, default: 1]

      defpdu TopPdu,
        aField: [size: 24]
        subPdu: [type: :subrecord, default: %SupPud{}]

  ### encode/decode
  Defines a custom encode or decode function. See type specifications for the function specification. If a PDU has a custom encode function defined it must also define
  a custom decode function. Custom encode and decode functions can override any of the other parameters the field has if the user wishes it so.

      defpdu CustomPdu,
        normalField: [size: 16, default: 3]
        customField: [encode: fn(val) -> << val :: size(12) >> end,
                      decode: fn(pdu, << val :: size(12) >>) -> {struct(pdu, :customField => val), <<>>} end]

  
  """
  @spec defpdu(pduName, [{fieldName, fieldParam}]) :: none
  defmacro defpdu name, originalFieldList do
    fieldList = for {fieldName, props} <- originalFieldList do
      fieldSize = props[:size]    
      case {props[:encode], props[:decode]} do
        {nil, nil} -> 
          customEncodeFun = 
          case props[:type] do
            :subrecord -> quote do fn(fieldVal) -> << Exgencode.Pdu.encode(fieldVal) :: bitstring >> end end
            :constant -> quote do fn(_) -> << unquote(props)[:default] :: size(unquote(fieldSize)) >> end end              
            _ -> quote do fn(fieldVal) -> << fieldVal :: size(unquote(fieldSize))>> end end
          end  
          customDecodeFun = 
          case props[:type] do
            :subrecord -> 
              quote do fn(pdu, binary) -> 
                {fieldValue, restBinary} = Exgencode.Pdu.decode(unquote(props)[:default], binary)
                {Map.replace(pdu, unquote(fieldName), fieldValue), restBinary}  end end
            :constant ->
              defVal = props[:default]
              quote do fn(pdu, << unquote(defVal) :: size(unquote(fieldSize)), restBinary :: bitstring >>) -> {pdu, restBinary} end end
            _ ->
              fieldSize = props[:size]
              quote do fn(pdu, << fieldValue :: size(unquote(fieldSize)), restBinary :: bitstring >>) -> {struct(pdu, %{unquote(fieldName) => fieldValue}), restBinary} end end
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
        fields = for {fieldName, props} <- unquote(fieldList), props[:type] != :constant do {fieldName, props[:default]} end
        defstruct fields
        
        @type t ::  %unquote(name){}
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
