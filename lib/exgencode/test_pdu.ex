defmodule Exgencode.TestPdu do
  @moduledoc false
  # This is an internal testing file - it is been build due to protocol consolidation

  require Exgencode
  import Exgencode

  defpdu MsgSubSection, someField: [default: 15, size: 8]

  defpdu PzTestMsg,
    testField: [default: 1, size: 12],
    otherTestField: [size: 24],
    subSection: [default: %MsgSubSection{}, type: :subrecord],
    constField: [default: 10, size: 28, type: :constant]

  defpdu CustomEncodeMsg,
    randomField: [size: 8],
    customField: [
      encode: fn _ -> <<6::size(8)>> end,
      decode: fn pdu, <<_::size(8), rest::bitstring>> ->
        {Map.replace!(pdu, :customField, 6), rest}
      end
    ]

  defpdu VersionedMsg,
    oldField: [default: 10, size: 16],
    newerField: [size: 8, version: ">= 2.0.0"],
    evenNewerField: [
      size: 8,
      version: ">= 2.1.0",
      encode: fn val -> <<val * 2::size(8)>> end,
      decode: fn pdu, <<val::size(8), rest::bitstring>> ->
        {struct(pdu, %{evenNewerField: div(val, 2)}), rest}
      end
    ]

  defpdu EndianMsg,
    bigField: [default: 15, size: 32, endianness: :big],
    smallField: [default: 15, size: 32, endianness: :little]

  defpdu FloatMsg,
    floatField: [size: 32, type: :float],
    littleFloatField: [size: 64, type: :float, endianness: :little]

  defpdu BinaryMsg,
    someHeader: [size: 8, default: 10],
    binaryField: [size: 16, type: :binary]

  defpdu StringMsg,
    someHeader: [size: 8, default: 10],
    stringField: [size: 16, type: :string]

  ### PDUs for doctest

  defpdu CustomPdu,
    normalField: [size: 16, default: 3],
    customField: [
      encode: fn val -> <<val * 2::size(16)>> end,
      decode: fn pdu, <<val::size(16)>> -> {struct(pdu, %{customField: div(val, 2)}), <<>>} end
    ]

  defpdu PduWithConstant, aConstantField: [size: 16, default: 10, type: :constant]

  defpdu SubPdu, someField: [size: 16, default: 1]

  defpdu TopPdu,
    aField: [size: 24],
    subPdu: [type: :subrecord, default: %SubPdu{}]

  defpdu VirtualPdu,
    real_field: [size: 16],
    virtual_field: [type: :virtual]

  defpdu VariablePdu,
    some_field: [size: 16],
    size_field: [size: 16],
    variable_field: [type: :variable, size: :size_field]

  defpdu OtherVariablePdu,
    some_field: [size: 16],
    size_field: [size: 16],
    variable_field: [type: :variable, size: :size_field],
    trailing_field: [size: 8]

  defpdu ConditionalPdu,
    normal_field: [size: 16],
    flag_field: [size: 8],
    conditional_field: [size: 8, conditional: :flag_field],
    another_normal_field: [size: 8],
    second_flag: [size: 8],
    size_field: [size: 16, conditional: :second_flag],
    conditional_variable_field: [type: :variable, size: :size_field, conditional: :second_flag]

  defpdu OffsetPdu,
    offset_to_field_a: [size: 16, offset_to: :field_a],
    offset_to_field_b: [size: 16, offset_to: :field_b],
    offset_to_field_c: [size: 16, offset_to: :field_c],
    field_a: [size: 8],
    size_field: [size: 16],
    variable_field: [type: :variable, size: :size_field],
    field_b: [size: 8],
    field_c: [size: 8, conditional: :offset_to_field_c]

  defpdu SomeSubPdu,
    size_field: [size: 16],
    variable_field: [type: :variable, size: :size_field]

  defpdu OffsetSubPdu,
    offset_to_first_sub: [size: 16, offset_to: :first_sub],
    offset_to_second_sub: [size: 16, offset_to: :second_sub],
    static_field: [size: 8],
    first_sub: [type: :subrecord, default: %SomeSubPdu{}, conditional: :offset_to_first_sub],
    second_sub: [type: :subrecord, default: %SomeSubPdu{}, conditional: :offset_to_first_sub]

  defpdu VersionedOffsetPdu,
    offset_to_something: [size: 16, offset_to: :something],
    static_field: [size: 8],
    versioned_field: [size: 16, version: ">= 2.0.0"],
    something: [size: 8, conditional: :offset_to_something]

  defpdu SlipHeaders,
    to_device_type: [default: 0, size: 8],
    to_device_number: [default: 0, size: 8],
    from_device_type: [default: 0, size: 8],
    from_device_number: [default: 0, size: 8],
    packet_type: [default: 0, size: 8],
    packet_sub_type: [default: 0, size: 8],
    service_type: [default: 0, size: 8],
    version_number: [default: 1, size: 8],
    offset_to_id: [default: 0, size: 8],
    offset_to_service_info: [default: 0, size: 8],
    offset_to_message_info: [default: 0, size: 8],
    offset_to_next_offset: [default: 0, size: 8],
    from_system_id: [type: :virtual],
    from_wacn_id: [type: :virtual]

  defpdu GroupGrantOcp,
    headers: [
      default: %SlipHeaders{},
      type: :subrecord
    ],
    # ID Section
    group_addr: [default: 0, size: 24],
    source_addr: [default: 0, size: 24],
    wacn_id: [default: 0, size: 24],
    system_id: [default: 0, size: 16],
    unit_id: [default: 0, size: 24],
    # Service Info Section
    logical_channel_number: [default: 0, size: 8],
    call_number: [default: 0, size: 16],
    source_site: [default: 0, size: 8],
    modulation_type: [default: 0, size: 4],
    call_priority: [default: 0, size: 4],
    sef: [default: 0, size: 1],
    pf: [default: 0, size: 1],
    priority: [default: 0, size: 3],
    reliability: [default: 0, size: 3],
    lmf: [default: 0, size: 1],
    cmf: [default: 0, size: 1],
    osf: [default: 0, size: 1],
    irf: [default: 0, size: 1],
    pmf: [default: 0, size: 1],
    ttf: [default: 0, size: 1],
    ef: [default: 0, size: 1],
    sf: [default: 0, size: 1],
    cf: [default: 0, size: 1],
    df: [default: 0, size: 1],
    grant_type: [default: 0, size: 3],
    call_state: [default: 0, size: 3],
    aa_id: [default: 0, size: 32],
    mc_id: [default: 0, size: 32],
    source_urid: [default: 0, size: 32],
    suf: [default: 0, size: 1],
    tef: [default: 0, size: 1],
    _reserved: [default: 0, size: 2],
    access_type: [default: 0, size: 3],
    destination_flag: [default: 0, size: 1],
    slot_bitmap: [default: 0, size: 8],
    # Next Offset Section
    offset_to_alias: [default: 0, size: 16, offset_to: :individual_alias_and_id_length],
    offset_to_data_info: [default: 0, size: 16, offset_to: :message_type_sc],
    offset_to_location_info: [default: 0, size: 16, offset_to: :location_on_receive_cadence],
    offset_to_next_offset: [default: 0, size: 16],
    # Alias Section
    individual_alias_and_id_length: [size: 8, conditional: :offset_to_alias],
    individual_alias_and_id: [
      type: :variable,
      size: :individual_alias_and_id_length,
      conditional: :offset_to_alias
    ],
    # Data Info Section
    message_type_sc: [size: 8, conditional: :offset_to_data_info],
    data_native_talkgroup_and_message_id: [
      size: 104,
      conditional: :offset_to_data_info
    ],
    data_payload_size: [size: 16, conditional: :offset_to_data_info],
    data_payload: [type: :variable, size: :data_payload_size, conditional: :offset_to_data_info],
    # Location Info Section
    location_on_receive_cadence: [size: 16, conditional: :offset_to_location_info]
end
