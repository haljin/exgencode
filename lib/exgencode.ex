defmodule Exgencode do
  @moduledoc """
  Documentation for Exgencode.
  """

  defprotocol Pdu.Protocol do
    @doc "Returns the size of the field in bits."
    def sizeof(pdu, fieldName)
    @doc "Encode the Elixir structure into a binary give the protocol version."
    @spec encode(Exgencode.pdu, nil | Version.version) :: binary
    def encode(pdu, version)
    @doc "Decode a binary into the specified Elixir structure."
    @spec decode(Exgencode.pdu, binary, nil | Version.version) :: {Exgencode.pdu, binary}
    def decode(pdu, binary, version)
  end

  @typedoc "A PDU, that is an Elixir structure representing a PDU."
  @type pdu :: map()
  @typedoc "PDU name, must be a structure name"
  @type pduName :: module
  @typedoc "The type of the field."
  @type fieldType :: :subrecord | :constant | :string | :binary | :float | :integer
  @typedoc "A custom encoding function that is meant to take the value of the field and return its binary represantion."
  @type fieldEncodeFun :: ((term) -> bitstring)
  @typedoc "A custom decoding function that receives the PDU decoded so far and remaining binary and is meant to return PDU with the field decoded and remaining binary."
  @type fieldDecodeFun :: ((pdu, bitstring) -> {pdu, bitstring})
  @typedoc "The endianness the field should be encoded/decoded with"
  @type fieldEndianness :: :big | :little | :native
  @typedoc "Parameters of the given field"
  @type fieldParam :: {:size, non_neg_integer} | {:type, fieldType} | {:encode, fieldEncodeFun} | {:decode, fieldDecodeFun} | {:version, Version.requirement} | {:endianness, fieldEndianness}
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
    
      defpdu SomePdu,
        someField: [size: 12]

  ### default
  Defines the default value that the field should assume when building a new Elixir structure of the given PDU.

      defpdu PduWithDefault,
        aFieldWithDefault: [size: 10, default: 15]

  ### type
  Defines the type of the field. Field can be of `:constant`, `:subrecord`, `:string`, `:binary`, `:float` and `:integer` types. 
  If no type should is specified it will default to `:integer`. Both `:integer` and `:float` specify normal numerical values and have no special properties.
  
  #### :constant
  If the field is constant it will not become part of the Elixir structure and will not be accessible. However it will still be 
  encoded into the binary representation and the decoding will expect the field to be present and have the given value in the decoded binary. Otherwise
  FunctionClauseError will be raised. A :constant field MUST have a default value specified.

      defpdu PduWithConstant,
        aConstantField: [size: 12, default: 10, type: :constant]

      iex> Exgencode.Pdu.encode(%TestPdu.PduWithConstant{})
      << 10 :: size(12) >>
      iex> %TestPdu.PduWithConstant{}.aConstantField
      ** (KeyError) key :aConstantField not found in: %Exgencode.TestPdu.PduWithConstant{}


  #### :subrecord
  If the field is meant to contain a sub-structure then it should be of type :subrecord. Such field must have either a default value specified that is of the
  type of the subrecord. Alternatively it must define custom decode and encode functions.

  #### Examples:

      defpdu SubPdu,
        someField: [size: 10, default: 1]

      defpdu TopPdu,
        aField: [size: 24],
        subPdu: [type: :subrecord, default: %SupPdu{}]

      iex> Exgencode.Pdu.encode(%TestPdu.TopPdu{aField: 24})
      << 24 :: size(24), 1 :: size(10) >>

      iex> Exgencode.Pdu.decode(%TestPdu.TopPdu{}, << 24 :: size(24), 1 :: size(10) >>)
      {%TestPdu.TopPdu{aField: 24, subPdu: %TestPdu.SubPdu{someField: 1}}, <<>>}

  #### :binary
  If the field is an arbitrary binary value it can be specified with this type. In such case the size parameter indicates size in bytes 
  rather than bits. This type does not define any padding, that is the size of the binary that is contained in this field must be of at least the defined field size,
  otherwise an `ArgumentError` is raised. If the size is larger the binary will be trimmed.

  #### Examples:

      defpdu BinaryMsg,
        someHeader: [size: 8, default: 10],
        binaryField: [size: 12, type: :binary]  

      iex> Exgencode.Pdu.encode(%TestPdu.BinaryMsg{binaryField: "12characters"})  
      << 10 :: size(8), "12characters" :: binary>>


  #### :string
  The `:string` type is similar to `:binary`, however it will not raise any errors if the length of the value to be encoded is different than declared field size.
  Instead, the string will be trimmed if its too long and padded with trailing 0-bytes if it is too short. Upon decoded all trailing 0-bytes will be removed.

  For any other handling of padding or empty bytes custom decode and encode functions must be defined.

  #### Examples:

      defpdu StringMsg,
        someHeader: [size: 8, default: 10], 
        stringField: [size: 12, type: :string]
        
      iex> Exgencode.Pdu.encode(%TestPdu.StringMsg{stringField: "12characters"})
      << 10 :: size(8), "12characters" :: binary>>

      iex> Exgencode.Pdu.encode(%TestPdu.StringMsg{stringField: "Too long string for field size"})
      << 10 :: size(8), "Too long str" :: binary>>

      iex> Exgencode.Pdu.encode(%TestPdu.StringMsg{stringField: "Too short"})
      << 10 :: size(8), "Too short" :: binary, 0, 0, 0>>

      iex> Exgencode.Pdu.decode(%TestPdu.StringMsg{}, << 10 :: size(8), "Too short" :: binary, 0, 0, 0>>)
      {%TestPdu.StringMsg{stringField: "Too short"}, <<>>}


  ### encode/decode
  Defines a custom encode or decode function. See type specifications for the function specification. If a PDU has a custom encode function defined it must also define
  a custom decode function. Custom encode and decode functions can override any of the other parameters the field has if the user wishes it so.

  #### Examples:

      defpdu CustomPdu,
        normalField: [size: 16, default: 3],
        customField: [encode: fn(val) -> << val * 2 :: size(12) >> end,
                      decode: fn(pdu, << val :: size(12) >>) -> {struct(pdu, %{customField: div(val, 2)}), <<>>} end]

      iex> Exgencode.Pdu.encode(%TestPdu.CustomPdu{customField: 10})
      << 3 :: size(16), 20 :: size(12) >>

      iex> Exgencode.Pdu.decode(%TestPdu.CustomPdu{}, << 3 :: size(16), 20 :: size(12) >>)
      {%TestPdu.CustomPdu{customField: 10}, <<>>}

  ### version
  Defines the requirement for the protocol version for the given field to be included in the message. When a version is specified `encode/2` and `decode/3` can take
  an optional parameter with the given version name. If the given version matches the version requirement defined by this option in the PDU definition, the field will
  be included. Otherwise it will be skipped. 

      defpdu VersionedMsg,
        oldField: [default: 10, size: 16],
        newerField: [size: 8, version: ">= 2.0.0"],

  See documentation for `Exgencode.Pdu./2` for examples.

  ### endianness
  Defines the endianness of the particular field. Allowed options are `:big`, `:little` and `:native`. Defaults to `:big`

  #### Examples:

      defpdu EndianMsg,
        bigField: [default: 15, size: 32, endianness: :big],
        smallField: [default: 15, size: 32, endianness: :little]

      iex> Exgencode.Pdu.encode(%TestPdu.EndianMsg{})
      << 15 :: big-size(32), 15 :: little-size(32)>>

  
  """
  @spec defpdu(pduName, [{fieldName, fieldParam}]) :: any
  defmacro defpdu name, originalFieldList do
    fieldList = for {fieldName, props} <- originalFieldList do
      fieldSize = props[:size]    
      endianness = Access.get(props, :endianness, :big)
      fieldType = Access.get(props, :type, :integer)
      case {props[:encode], props[:decode]} do
        {nil, nil} -> 
          unless valid_field?(fieldType, props[:encode], fieldSize), do: raise_argument_error name, fieldName, "Size must be defined unless a field is of type :subrecord or custom decode/encode functions are provided. Size of float must be 32 or 64."
          encodeFun = create_versioned_encode(create_encode_fun(fieldType, fieldSize, props[:default], endianness), props[:version])
          decodeFun = create_versioned_decode(create_decode_fun(fieldType, fieldSize, props[:default], fieldName, endianness), props[:version])
          {fieldName, [{:encode, encodeFun}, {:decode, decodeFun} | props]}
        {_encodeFun, nil} -> 
          raise_argument_error name, fieldName, "Cannot define custom encode without custom decode"
        {nil, _decodeFun} ->
          raise_argument_error name, fieldName, "Cannot define custom decode without custom encode"
        _ ->
          encodeFun = create_versioned_encode(props[:encode], props[:version])
          decodeFun = create_versioned_decode(props[:decode], props[:version])
          {fieldName, Keyword.replace!(Keyword.replace!(props, :encode, encodeFun), :decode, decodeFun)}
      end
    end
    
    fieldsForEncodes = for {fieldName, props} <- fieldList do {fieldName, props[:encode]} end
    fieldsForDencodes = for {fieldName, props} <- fieldList do {fieldName, props[:decode]} end
    quote do
      defmodule unquote(name) do
        @moduledoc false
        fields = for {fieldName, props} <- unquote(fieldList), props[:type] != :constant do {fieldName, props[:default]} end
        defstruct fields
        
        @type t ::  %unquote(name){}
      end

      defimpl Exgencode.Pdu.Protocol, for: unquote(name) do
        def sizeof(pdu, fieldName) do
          unquote(fieldList)[fieldName][:size]          
        end
        
        def encode(pdu, version) do
          for {field, encodeFun} <- unquote(fieldsForEncodes), into: <<>>, do: encodeFun.(version).(Map.get(pdu, field))
        end

        def decode(pdu, binary, version) do      
          do_decode(pdu, binary, unquote(fieldsForDencodes), version)
        end

        defp do_decode(pdu, binary, fields, version)
        defp do_decode(pdu, binary, [{field, decodeFun} | rest], version) do
          {newPdu, restBinary} = decodeFun.(version).(pdu, binary)
          do_decode(newPdu, restBinary, rest, version)
        end
        defp do_decode(pdu, restBin, [], _) do
          {pdu, restBin}
        end
      end
    end    
  end

  defp raise_argument_error(pduName, fieldName, msg) do
    raise ArgumentError, "Badly defined field #{inspect fieldName} in #{inspect pduName |> Macro.to_string} - " <> msg
  end

  defp valid_field?(:subrecord, _encodeFun, _size), do: true
  defp valid_field?(:float, nil, 32), do: true
  defp valid_field?(:float, nil, 64), do: true
  defp valid_field?(:float, nil, _), do: false
  defp valid_field?(_otherType, encodeFun, _size) when not is_nil(encodeFun), do: true
  defp valid_field?(_otherType, _encodeFun, size) when is_integer(size), do: true
  defp valid_field?(_, _, _), do: false

  defp create_versioned_encode(function, nil) do
    quote do: fn(_) -> unquote(function) end
  end
  defp create_versioned_encode(function, version) do
    quote do
      fn(nil) -> unquote(function)
        (ver) -> 
          if Version.match?(ver, unquote(version)) do
            unquote(function) 
          else
            fn(_) -> <<>> end
          end
      end
    end
  end
  
  defp create_versioned_decode(function, nil) do
    quote do: fn(_) -> unquote(function) end
  end
  defp create_versioned_decode(function, version) do
    quote do
      fn(nil) -> unquote(function)
        (ver) -> 
          if Version.match?(ver, unquote(version)) do
            unquote(function) 
          else
            fn(pdu, bin) -> {pdu, bin} end
          end
      end
    end
  end

  defp create_encode_fun(:subrecord, _fieldSize, _default, _endianness) do
    quote do: fn(fieldVal) -> << Exgencode.Pdu.encode(fieldVal) :: bitstring >> end 
  end
  defp create_encode_fun(:constant, fieldSize, default, endianness) do
    fieldEncodeType = Macro.var(endianness, __MODULE__) 
    quote do: fn(_) -> << unquote(default) :: unquote(fieldEncodeType)-size(unquote(fieldSize)) >> end 
  end               
  defp create_encode_fun(:string, fieldSize, _default, endianness) do
    fieldEndianType = Macro.var(endianness, __MODULE__) 
    fieldEncodeType = Macro.var(:binary, __MODULE__)
    quote do 
      fn(fieldVal) -> 
        paddedFieldVal = 
        cond do
          byte_size(fieldVal) == unquote(fieldSize) -> fieldVal
          byte_size(fieldVal) > unquote(fieldSize) -> binary_part(fieldVal, 0, unquote(fieldSize))
          byte_size(fieldVal) < unquote(fieldSize) -> fieldVal <> for _ <- 1..(unquote(fieldSize) - byte_size(fieldVal)), into: <<>>, do: <<0>> 
        end
        << paddedFieldVal :: unquote(fieldEndianType)-unquote(fieldEncodeType)-size(unquote(fieldSize))>> 
      end  
    end
  end        
  defp create_encode_fun(sizedType, fieldSize, _default, endianness) when sizedType == :integer 
                                                                     when sizedType == :float 
                                                                     when sizedType == :binary do
    fieldEndianType = Macro.var(endianness, __MODULE__) 
    fieldEncodeType = Macro.var(sizedType, __MODULE__)
    quote do: fn(fieldVal) -> << fieldVal :: unquote(fieldEndianType)-unquote(fieldEncodeType)-size(unquote(fieldSize))>> end  
  end

  defp create_decode_fun(:subrecord, _fieldSize, default, fieldName, _endianness) do    
    quote do 
      fn(pdu, binary) -> 
        {fieldValue, restBinary} = Exgencode.Pdu.decode(unquote(default), binary)
        {Map.replace(pdu, unquote(fieldName), fieldValue), restBinary}  
      end 
    end
  end
  defp create_decode_fun(:constant, fieldSize, default, _fieldName, endianness) do  
    fieldEncodeType = Macro.var(endianness, __MODULE__) 
    quote do: fn(pdu, << unquote(default) :: unquote(fieldEncodeType)-size(unquote(fieldSize)), restBinary :: bitstring >>) -> {pdu, restBinary} end 
  end
  defp create_decode_fun(:string, fieldSize, _default, fieldName, endianness)  do 
    fieldEndianType = Macro.var(endianness, __MODULE__) 
    fieldEncodeType = Macro.var(:binary, __MODULE__)
    quote do 
      fn(pdu, << fieldValue :: unquote(fieldEndianType)-unquote(fieldEncodeType)-size(unquote(fieldSize)), restBinary :: bitstring >>) -> 
        {struct!(pdu, %{unquote(fieldName) => String.trim_trailing(fieldValue, <<0>>)}), restBinary} 
      end 
    end
  end
  defp create_decode_fun(sizedType, fieldSize, _default, fieldName, endianness) when sizedType == :integer 
                                                                                when sizedType == :float 
                                                                                when sizedType == :binary do 
    fieldEndianType = Macro.var(endianness, __MODULE__) 
    fieldEncodeType = Macro.var(sizedType, __MODULE__)
    quote do 
      fn(pdu, << fieldValue :: unquote(fieldEndianType)-unquote(fieldEncodeType)-size(unquote(fieldSize)), restBinary :: bitstring >>) -> 
        {struct!(pdu, %{unquote(fieldName) => fieldValue}), restBinary} 
      end 
    end
  end

end
