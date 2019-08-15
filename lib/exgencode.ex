defmodule Exgencode do
  @moduledoc """
  Documentation for Exgencode.
  """

  defprotocol Pdu.Protocol do
    @doc "Returns the size of the field in bits."
    def sizeof(pdu, field_name)
    @doc "Returns the size of the pdu for given version (does not count subrecords size)."
    @spec sizeof_pdu(Exgencode.pdu(), Version.version() | nil, Exgencode.return_size_type()) ::
            non_neg_integer | {:subrecord, Exgencode.pdu()}
    def sizeof_pdu(pdu, version, type)
    @doc "Encode the Elixir structure into a binary give the protocol version."
    @spec encode(Exgencode.pdu(), nil | Version.version()) :: binary
    def encode(pdu, version)
    @doc "Decode a binary into the specified Elixir structure."
    @spec decode(Exgencode.pdu(), binary, nil | Version.version()) :: {Exgencode.pdu(), binary}
    def decode(pdu, binary, version)
  end

  @typedoc "A PDU, that is an Elixir structure representing a PDU."
  @type pdu :: struct
  @typedoc "PDU name, must be a structure name"
  @type pdu_name :: module
  @typedoc "The type of the field."
  @type field_type :: :subrecord | :constant | :string | :binary | :float | :integer
  @typedoc "A custom encoding function that is meant to take the value of the field and return its binary represantion."
  @type field_encode_fun :: (term -> bitstring)
  @typedoc "A custom decoding function that receives the PDU decoded so far and remaining binary and is meant to return PDU with the field decoded and remaining binary."
  @type field_decode_fun :: (pdu, bitstring -> {pdu, bitstring})
  @typedoc "The endianness the field should be encoded/decoded with"
  @type field_endianness :: :big | :little | :native
  @typedoc "Parameters of the given field"
  @type fieldParam ::
          {:size, non_neg_integer}
          | {:type, field_type}
          | {:encode, field_encode_fun}
          | {:decode, field_decode_fun}
          | {:version, Version.requirement()}
          | {:endianness, field_endianness}
  @typedoc "Name of the field."
  @type field_name :: atom
  @typedoc "Desired return type of pdu size"
  @type return_size_type :: :bits | :bytes

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
  Defines the type of the field. Field can be of type:
  * `:constant`
  * `:subrecord`
  * `:string`
  * `:binary`
  * `:float`
  * `:integer`
  * `:variable`

  If no type should is specified it will default to `:integer`. Both `:integer` and `:float` specify normal numerical values and have no special properties.

  #### :constant
  If the field is constant it will not become part of the Elixir structure and will not be accessible. However it will still be
  encoded into the binary representation and the decoding will expect the field to be present and have the given value in the decoded binary. Otherwise
  FunctionClauseError will be raised. A :constant field MUST have a default value specified.

      defpdu PduWithConstant,
        aConstantField: [size: 12, default: 10, type: :constant]

      iex> Exgencode.Pdu.encode(%TestPdu.PduWithConstant{})
      << 10 :: size(16) >>
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
      << 24 :: size(24), 1 :: size(16) >>

      iex> Exgencode.Pdu.decode(%TestPdu.TopPdu{}, << 24 :: size(24), 1 :: size(16) >>)
      {%TestPdu.TopPdu{aField: 24, subPdu: %TestPdu.SubPdu{someField: 1}}, <<>>}

  #### :virtual
  The virtual fields are never encoded into binaries and exist only in the Elixir structs. When decoding into a struct
  the virtual field will always assume the default value.

  #### Examples:

      defpdu VirtualPdu,
        real_field: [size: 16],
        virtual_field: [type: :virtual]

      iex> Exgencode.Pdu.encode(%TestPdu.VirtualPdu{real_field: 12, virtual_field: "Any value goes here"})
      <<12::size(16)>>

      iex> Exgencode.Pdu.decode(%TestPdu.VirtualPdu{}, <<12::size(16)>>)
      {%TestPdu.VirtualPdu{real_field: 12, virtual_field: nil}, <<>>}

  #### :binary
  If the field is an arbitrary binary value it can be specified with this type. In such case the size parameter indicates size in bytes
  rather than bits. This type does not define any padding, that is the size of the binary that is contained in this field must be of at least the defined field size,
  otherwise an `ArgumentError` is raised. If the size is larger the binary will be trimmed.

  #### :variable
  Variable fields have no pre-defined size, instead the size is defined by the value of another field. When defining a `:variable` field, the
  `:size` parameter must be set to the name of the field definining the size, which in turn should be an `:integer` field. The size in that case
  can only be specified in bytes. All `:variable` fields are binary fields.

  #### Examples:
      defpdu VariablePdu,
        some_field: [size: 16],
        size_field: [size: 16],
        variable_field: [type: :variable, size: :size_field]

      iex> Exgencode.Pdu.encode(%TestPdu.VariablePdu{some_field: 52, size_field: 2, variable_field: "AB"})
      <<52::size(16), 2::size(16), "A", "B">>

      iex> Exgencode.Pdu.decode(%TestPdu.VariablePdu{}, <<52::size(16), 2::size(16), "A", "B">>)
      {%TestPdu.VariablePdu{some_field: 52, size_field: 2, variable_field: "AB"}, <<>>}

  Note that the field defining the size must be defined before the variable length field.

  #### Examples:

      defpdu BinaryMsg,
        someHeader: [size: 8, default: 10],
        binaryField: [size: 16, type: :binary]

      iex> Exgencode.Pdu.encode(%TestPdu.BinaryMsg{binaryField: "16charactershere"})
      << 10 :: size(8), "16charactershere" :: binary>>

  #### :string
  The `:string` type is similar to `:binary`, however it will not raise any errors if the length of the value to be encoded is different than declared field size.
  Instead, the string will be trimmed if its too long and padded with trailing 0-bytes if it is too short. Upon decoded all trailing 0-bytes will be removed.

  For any other handling of padding or empty bytes custom decode and encode functions must be defined.

  #### Examples:

      defpdu StringMsg,
        someHeader: [size: 8, default: 10],
        stringField: [size: 16, type: :string]

      iex> Exgencode.Pdu.encode(%TestPdu.StringMsg{stringField: "16charactershere"})
      << 10 :: size(8), "16charactershere" :: binary>>

      iex> Exgencode.Pdu.encode(%TestPdu.StringMsg{stringField: "Too long string for field size"})
      << 10 :: size(8), "Too long string " :: binary>>

      iex> Exgencode.Pdu.encode(%TestPdu.StringMsg{stringField: "Too short"})
      << 10 :: size(8), "Too short" :: binary, 0, 0, 0, 0, 0, 0, 0>>

      iex> Exgencode.Pdu.decode(%TestPdu.StringMsg{}, << 10 :: size(8), "Too short" :: binary, 0, 0, 0, 0, 0, 0, 0>>)
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
      << 3 :: size(16), 20 :: size(16) >>

      iex> Exgencode.Pdu.decode(%TestPdu.CustomPdu{}, << 3 :: size(16), 20 :: size(16) >>)
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
  @spec defpdu(pdu_name, [{field_name, fieldParam}]) :: any
  defmacro defpdu name, original_field_list do
    check_pdu_size(name, original_field_list)

    field_list = map_fields(name, original_field_list)

    fields_for_encodes =
      Enum.map(field_list, fn {field_name, props} ->
        {field_name, props[:encode]}
      end)

    fields_for_decodes =
      Enum.map(field_list, fn {field_name, props} ->
        {field_name, props[:decode]}
      end)

    struct_fields =
      for {field_name, props} <- field_list, props[:type] != :constant do
        {field_name, props[:default]}
      end

    out =
      quote do
        defmodule unquote(name) do
          @moduledoc false

          defstruct unquote(struct_fields)

          @type t :: %unquote(name){}
        end

        defimpl Exgencode.Pdu.Protocol, for: unquote(name) do
          unquote(Exgencode.Sizeof.build_sizeof(field_list))
          unquote(Exgencode.Sizeof.build_sizeof_pdu(field_list))

          def encode(pdu, version) do
            for {field, encode_fun} <- unquote(fields_for_encodes),
                into: <<>>,
                do: encode_fun.(version).(pdu)
          end

          def decode(pdu, binary, version) do
            do_decode(pdu, binary, unquote(fields_for_decodes), version)
          end

          defp do_decode(pdu, binary, [{field, decode_fun} | rest], version) do
            {new_pdu, rest_binary} = decode_fun.(version).(pdu, binary)
            do_decode(new_pdu, rest_binary, rest, version)
          end

          defp do_decode(pdu, rest_bin, [], _) do
            {pdu, rest_bin}
          end
        end
      end

    File.write("#{Macro.to_string(name)}.ex", Macro.to_string(out))
    out
  end

  defp map_fields(name, original_field_list) do
    for {field_name, props} <- original_field_list do
      field_size = props[:size]
      endianness = Access.get(props, :endianness, :big)
      field_type = Access.get(props, :type, :integer)

      case {props[:encode], props[:decode]} do
        {nil, nil} ->
          unless valid_field_size?(field_type, props[:encode], field_size),
            do:
              raise_argument_error(
                name,
                field_name,
                "Size must be defined unless a field is of type :subrecord or :virtual or custom decode/encode functions are provided. Size of float must be 32 or 64. :variable type fields must specify the name of the field defining their size."
              )

          encode_fun =
            Exgencode.EncodeDecode.create_versioned_encode(
              Exgencode.EncodeDecode.create_encode_fun(
                field_type,
                field_name,
                field_size,
                props[:default],
                endianness
              ),
              props[:version]
            )

          decode_fun =
            Exgencode.EncodeDecode.create_versioned_decode(
              Exgencode.EncodeDecode.create_decode_fun(
                field_type,
                field_size,
                props[:default],
                field_name,
                endianness
              ),
              props[:version]
            )

          {field_name, [{:encode, encode_fun}, {:decode, decode_fun} | props]}

        {_encode_fun, nil} ->
          raise_argument_error(
            name,
            field_name,
            "Cannot define custom encode without custom decode"
          )

        {nil, _decode_fun} ->
          raise_argument_error(
            name,
            field_name,
            "Cannot define custom decode without custom encode"
          )

        _ ->
          encode_fun =
            Exgencode.EncodeDecode.create_versioned_encode(
              Exgencode.EncodeDecode.wrap_custom_encode(field_name, props[:encode]),
              props[:version]
            )

          decode_fun =
            Exgencode.EncodeDecode.create_versioned_decode(props[:decode], props[:version])

          {field_name,
           props
           |> Keyword.replace!(:encode, encode_fun)
           |> Keyword.replace!(:decode, decode_fun)}
      end
    end
  end

  defp check_pdu_size(pdu_name, fields) do
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

  defp valid_field_size?(:subrecord, _encode_fun, _size), do: true
  defp valid_field_size?(:virtual, _encode_fun, _size), do: true
  defp valid_field_size?(:float, nil, 32), do: true
  defp valid_field_size?(:float, nil, 64), do: true
  defp valid_field_size?(:float, nil, _), do: false
  defp valid_field_size?(:variable, nil, name) when is_atom(name), do: true
  defp valid_field_size?(:variable, nil, _name), do: false
  defp valid_field_size?(_other_type, encode_fun, _size) when not is_nil(encode_fun), do: true
  defp valid_field_size?(_other_type, _encode_fun, size) when is_integer(size), do: true
  defp valid_field_size?(_, _, _), do: false
end
