defmodule ExgencodeTest do
  use ExUnit.Case
  alias Exgencode.TestPdu
  doctest Exgencode.Pdu
  doctest Exgencode

  test "basic pdu definition" do
    pdu = %TestPdu.PzTestMsg{}
    assert pdu.testField == 1
    assert Exgencode.Pdu.sizeof(%TestPdu.PzTestMsg{}, :testField) == 12
    assert pdu.otherTestField == nil
    assert pdu.subSection == %TestPdu.MsgSubSection{}
    assert_raise KeyError, fn -> pdu.constField end
  end

  test "encoding" do
    pdu = %TestPdu.PzTestMsg{otherTestField: 100}
    assert <<1::size(12), 100::size(24), 15::size(8), 10::size(28)>> == Exgencode.Pdu.encode(pdu)
  end

  test "decoding" do
    pdu = %TestPdu.PzTestMsg{otherTestField: 100}
    binary = <<1::size(12), 100::size(24), 15::size(8), 10::size(28)>>
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.PzTestMsg{}, binary)
  end

  test "incorrect constant fails" do
    pdu = %TestPdu.PzTestMsg{otherTestField: 100}
    binary = <<1::size(12), 100::size(24), 15::size(8), 99::size(24)>>

    assert_raise FunctionClauseError, fn ->
      {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.PzTestMsg{}, binary)
    end
  end

  test "custom encode" do
    pdu = %TestPdu.CustomEncodeMsg{randomField: 0}
    assert <<0, 6>> == Exgencode.Pdu.encode(pdu)
  end

  test "custom decode" do
    pdu = %TestPdu.CustomEncodeMsg{randomField: 0, customField: 6}
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.CustomEncodeMsg{}, <<0, 6>>)
  end

  test "encode/decode symmetry" do
    pdu = %TestPdu.PzTestMsg{otherTestField: 100}
    custom_pdu = %TestPdu.CustomEncodeMsg{randomField: 0, customField: 6}
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.PzTestMsg{}, Exgencode.Pdu.encode(pdu))

    assert {^custom_pdu, <<>>} =
             Exgencode.Pdu.decode(%TestPdu.CustomEncodeMsg{}, Exgencode.Pdu.encode(custom_pdu))
  end

  test "versioning encode" do
    pdu = %TestPdu.VersionedMsg{newerField: 111, evenNewerField: 7}
    assert <<10::size(16), 111::size(8), 14::size(8)>> == Exgencode.Pdu.encode(pdu)
    assert <<10::size(16)>> == Exgencode.Pdu.encode(pdu, "1.0.0")
    assert <<10::size(16), 111::size(8)>> == Exgencode.Pdu.encode(pdu, "2.0.0")
    assert <<10::size(16), 111::size(8), 14::size(8)>> == Exgencode.Pdu.encode(pdu, "2.1.0")
  end

  test "versioning decode" do
    pdu = %TestPdu.VersionedMsg{}
    binary = <<10::size(16)>>
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, binary, "1.0.0")

    pdu = %TestPdu.VersionedMsg{newerField: 111}
    binary = <<10::size(16), 111::size(8)>>
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, binary, "2.0.0")

    pdu = %TestPdu.VersionedMsg{newerField: 111, evenNewerField: 7}
    binary = <<10::size(16), 111::size(8), 14::size(8)>>
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, binary)
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, binary, "2.1.0")

    assert {%TestPdu.VersionedMsg{}, <<111::size(8), 14::size(8)>>} =
             Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, binary, "1.0.0")
  end

  test "versioned encode/decode symmetry" do
    pdu = %TestPdu.VersionedMsg{}

    assert {^pdu, <<>>} =
             Exgencode.Pdu.decode(
               %TestPdu.VersionedMsg{},
               Exgencode.Pdu.encode(pdu, "1.0.0"),
               "1.0.0"
             )

    pdu = %TestPdu.VersionedMsg{newerField: 111}

    assert {^pdu, <<>>} =
             Exgencode.Pdu.decode(
               %TestPdu.VersionedMsg{},
               Exgencode.Pdu.encode(pdu, "2.0.0"),
               "2.0.0"
             )

    pdu = %TestPdu.VersionedMsg{newerField: 111, evenNewerField: 7}

    assert {^pdu, <<>>} =
             Exgencode.Pdu.decode(
               %TestPdu.VersionedMsg{},
               Exgencode.Pdu.encode(pdu, "2.1.0"),
               "2.1.0"
             )
  end

  test "endianness" do
    pdu = %TestPdu.EndianMsg{}
    bin = <<15::big-size(32), 15::little-size(32)>>
    assert ^bin = Exgencode.Pdu.encode(pdu)
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(pdu, bin)
  end

  test "float types" do
    pdu = %TestPdu.FloatMsg{floatField: 1.25, littleFloatField: 1.125}
    bin = <<1.25::float-size(32), 1.125::little-float-size(64)>>
    assert ^bin = Exgencode.Pdu.encode(pdu)
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(pdu, bin)
  end

  test "binary types" do
    pdu = %TestPdu.BinaryMsg{binaryField: "16charactershere"}
    bin = <<10::size(8), "16charactershere"::binary>>
    assert ^bin = Exgencode.Pdu.encode(pdu)
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(pdu, bin)

    pdu = %TestPdu.BinaryMsg{binaryField: "tooshort"}
    assert_raise ArgumentError, fn -> Exgencode.Pdu.encode(pdu) end

    pdu = %TestPdu.BinaryMsg{binaryField: "way too long for the field"}
    bin = <<10::size(8), "way too long for"::binary>>
    assert ^bin = Exgencode.Pdu.encode(pdu)
  end

  test "string types" do
    pdu = %TestPdu.StringMsg{stringField: "16charactershere"}
    bin = <<10::size(8), "16charactershere"::binary>>
    assert ^bin = Exgencode.Pdu.encode(pdu)
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(pdu, bin)

    pdu = %TestPdu.StringMsg{stringField: "Too long string for field size"}
    bin = <<10::size(8), "Too long string "::binary>>
    assert ^bin = Exgencode.Pdu.encode(pdu)

    pdu = %TestPdu.StringMsg{stringField: "Too short"}
    bin = <<10::size(8), "Too short"::binary, 0, 0, 0, 0, 0, 0, 0>>
    assert ^bin = Exgencode.Pdu.encode(pdu)
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(pdu, bin)
  end

  test "size of versioned pdu" do
    pdu = %TestPdu.VersionedMsg{}
    nested_pdu = %TestPdu.TopPdu{}
    assert 24 == Exgencode.Pdu.sizeof_pdu(pdu, "2.0.0")
    assert 32 == Exgencode.Pdu.sizeof_pdu(pdu, "2.1.0")
    assert 32 == Exgencode.Pdu.sizeof_pdu(pdu)
    assert 40 == Exgencode.Pdu.sizeof_pdu(nested_pdu)
    assert 3 == Exgencode.Pdu.sizeof_pdu(pdu, "2.0.0", :bytes)
    assert 4 == Exgencode.Pdu.sizeof_pdu(pdu, "2.1.0", :bytes)
    assert 4 == Exgencode.Pdu.sizeof_pdu(pdu, nil, :bytes)
    assert 5 == Exgencode.Pdu.sizeof_pdu(nested_pdu, nil, :bytes)
  end

  test "virtual fields" do
    pdu = %TestPdu.VirtualPdu{real_field: 52, virtual_field: :something_whatever}
    assert <<52::size(16)>> == Exgencode.Pdu.encode(pdu)

    assert {%TestPdu.VirtualPdu{
              real_field: 49,
              virtual_field: nil
            }, <<>>} == Exgencode.Pdu.decode(%TestPdu.VirtualPdu{}, <<49::size(16)>>)
  end

  test "variable length fields" do
    pdu = %TestPdu.VariablePdu{some_field: 52, size_field: 2, variable_field: "AB"}

    assert <<52::size(16), 2::size(16), "A", "B">> == Exgencode.Pdu.encode(pdu)

    assert {%TestPdu.VariablePdu{some_field: 52, size_field: 2, variable_field: "AB"}, <<>>} ==
             Exgencode.Pdu.decode(%TestPdu.VariablePdu{}, <<52::size(16), 2::size(16), "A", "B">>)
  end

  test "variable length fields with other lengths" do
    variable_val =
      "Quick brown fox jumps over the lazy dog. Quick brown fox jumps over the lazy dog.
      Quick brown fox jumps over the lazy dog. Quick brown fox jumps over the lazy dog.
      Quick brown fox jumps over the lazy dog."

    pdu = %TestPdu.VariablePdu{
      some_field: 52,
      size_field: byte_size(variable_val),
      variable_field: variable_val
    }

    assert <<52::size(16), byte_size(variable_val)::size(16)>> <> variable_val ==
             Exgencode.Pdu.encode(pdu)

    assert {%TestPdu.VariablePdu{
              some_field: 52,
              size_field: byte_size(variable_val),
              variable_field: variable_val
            },
            <<>>} ==
             Exgencode.Pdu.decode(
               %TestPdu.VariablePdu{},
               <<52::size(16), byte_size(variable_val)::size(16)>> <> variable_val
             )
  end

  test "variable length fields followed by normal fields" do
    variable_val =
      "Quick brown fox jumps over the lazy dog. Quick brown fox jumps over the lazy dog.
      Quick brown fox jumps over the lazy dog. Quick brown fox jumps over the lazy dog.
      Quick brown fox jumps over the lazy dog."

    pdu = %TestPdu.OtherVariablePdu{
      some_field: 52,
      size_field: byte_size(variable_val),
      variable_field: variable_val,
      trailing_field: 37
    }

    assert <<52::size(16), byte_size(variable_val)::size(16)>> <> variable_val <> <<37>> ==
             Exgencode.Pdu.encode(pdu)

    assert {%TestPdu.OtherVariablePdu{
              some_field: 52,
              size_field: byte_size(variable_val),
              variable_field: variable_val,
              trailing_field: 37
            },
            <<>>} ==
             Exgencode.Pdu.decode(
               %TestPdu.OtherVariablePdu{},
               <<52::size(16), byte_size(variable_val)::size(16)>> <> variable_val <> <<37>>
             )
  end

  test "size of variable pdus" do
    variable_val =
      "Quick brown fox jumps over the lazy dog. Quick brown fox jumps over the lazy dog.
      Quick brown fox jumps over the lazy dog. Quick brown fox jumps over the lazy dog.
      Quick brown fox jumps over the lazy dog."

    pdu = %TestPdu.OtherVariablePdu{
      some_field: 52,
      size_field: byte_size(variable_val),
      variable_field: variable_val,
      trailing_field: 37
    }

    assert bit_size(variable_val) == Exgencode.Pdu.sizeof(pdu, :variable_field)
    assert 16 + 16 + bit_size(variable_val) + 8 == Exgencode.Pdu.sizeof_pdu(pdu, nil, :bits)
  end

  test "conditional fields" do
    variable_val = "This is just a test."

    pdu = %TestPdu.ConditionalPdu{
      normal_field: 12,
      flag_field: 1,
      conditional_field: 10,
      another_normal_field: 200,
      second_flag: 1,
      size_field: byte_size(variable_val),
      conditional_variable_field: variable_val
    }

    assert <<12::size(16), 1, 10, 200, 1, byte_size(variable_val)::size(16)>> <> variable_val ==
             Exgencode.Pdu.encode(pdu)

    assert {pdu, <<>>} ==
             Exgencode.Pdu.decode(
               pdu,
               <<12::size(16), 1, 10, 200, 1, byte_size(variable_val)::size(16)>> <> variable_val
             )

    pdu2 = %TestPdu.ConditionalPdu{
      normal_field: 12,
      flag_field: 0,
      another_normal_field: 200,
      second_flag: 1,
      size_field: byte_size(variable_val),
      conditional_variable_field: variable_val
    }

    assert <<12::size(16), 0, 200, 1, byte_size(variable_val)::size(16)>> <> variable_val ==
             Exgencode.Pdu.encode(pdu2)

    assert {pdu2, <<>>} ==
             Exgencode.Pdu.decode(
               pdu2,
               <<12::size(16), 0, 200, 1, byte_size(variable_val)::size(16)>> <> variable_val
             )

    pdu3 = %TestPdu.ConditionalPdu{
      normal_field: 12,
      flag_field: 0,
      another_normal_field: 200,
      second_flag: 0
    }

    assert <<12::size(16), 0, 200, 0>> ==
             Exgencode.Pdu.encode(pdu3)

    assert {pdu3, <<>>} ==
             Exgencode.Pdu.decode(
               pdu3,
               <<12::size(16), 0, 200, 0>>
             )
  end

  test "sizeof conditional fields" do
    variable_val = "This is just a test."

    pdu = %TestPdu.ConditionalPdu{
      normal_field: 12,
      flag_field: 1,
      conditional_field: 10,
      another_normal_field: 200,
      second_flag: 1,
      size_field: byte_size(variable_val),
      conditional_variable_field: variable_val
    }

    assert 8 == Exgencode.Pdu.sizeof(pdu, :conditional_field)

    assert 16 + 8 + 8 + 8 + 8 + 16 + bit_size(variable_val) ==
             Exgencode.Pdu.sizeof_pdu(pdu, nil, :bits)

    pdu2 = %TestPdu.ConditionalPdu{
      normal_field: 12,
      flag_field: 0,
      another_normal_field: 200,
      second_flag: 1,
      size_field: byte_size(variable_val),
      conditional_variable_field: variable_val
    }

    assert 0 == Exgencode.Pdu.sizeof(pdu2, :conditional_field)
    assert bit_size(variable_val) == Exgencode.Pdu.sizeof(pdu2, :conditional_variable_field)

    assert 16 + 8 + 8 + 8 + 16 + bit_size(variable_val) ==
             Exgencode.Pdu.sizeof_pdu(pdu2, nil, :bits)

    pdu3 = %TestPdu.ConditionalPdu{
      normal_field: 12,
      flag_field: 0,
      another_normal_field: 200,
      second_flag: 0
    }

    assert 0 == Exgencode.Pdu.sizeof(pdu3, :conditional_field)
    assert 0 == Exgencode.Pdu.sizeof(pdu3, :conditional_variable_field)

    assert 16 + 8 + 8 + 8 ==
             Exgencode.Pdu.sizeof_pdu(pdu3, nil, :bits)
  end

  test "offset fields" do
    variable_val = "This is just a test."

    pdu = %TestPdu.OffsetPdu{
      field_a: 14,
      size_field: byte_size(variable_val),
      variable_field: variable_val,
      field_b: 15,
      field_c: 20
    }

    assert 6 ==
             [:offset_to_field_a, :offset_to_field_b, :offset_to_field_c]
             |> Enum.map(fn field_name -> Exgencode.Pdu.sizeof(pdu, field_name) end)
             |> Enum.sum()
             |> div(8)

    assert 9 + byte_size(variable_val) ==
             [
               :offset_to_field_a,
               :offset_to_field_b,
               :offset_to_field_c,
               :field_a,
               :size_field,
               :variable_field
             ]
             |> Enum.map(fn field_name -> Exgencode.Pdu.sizeof(pdu, field_name) end)
             |> Enum.sum()
             |> div(8)

    assert <<6::size(16), 9 + byte_size(variable_val)::size(16),
             10 + byte_size(variable_val)::size(16), 14,
             byte_size(variable_val)::size(16)>> <> variable_val <> <<15, 20>> ==
             Exgencode.Pdu.encode(pdu)

    assert {%TestPdu.OffsetPdu{
              pdu
              | offset_to_field_a: 6,
                offset_to_field_b: 29,
                offset_to_field_c: 30
            },
            <<>>} ==
             Exgencode.Pdu.decode(
               %TestPdu.OffsetPdu{},
               <<6::size(16), 9 + byte_size(variable_val)::size(16),
                 10 + byte_size(variable_val)::size(16), 14,
                 byte_size(variable_val)::size(16)>> <> variable_val <> <<15, 20>>
             )

    pdu2 = %TestPdu.OffsetPdu{
      field_a: 14,
      size_field: byte_size(variable_val),
      variable_field: variable_val,
      field_b: 15,
      field_c: nil
    }

    assert <<6::size(16), 9 + byte_size(variable_val)::size(16), 0::size(16), 14,
             byte_size(variable_val)::size(16)>> <> variable_val <> <<15>> ==
             Exgencode.Pdu.encode(pdu2)

    assert {%TestPdu.OffsetPdu{
              pdu2
              | offset_to_field_a: 6,
                offset_to_field_b: 29,
                offset_to_field_c: 0
            },
            <<>>} ==
             Exgencode.Pdu.decode(
               %TestPdu.OffsetPdu{},
               <<6::size(16), 9 + byte_size(variable_val)::size(16), 0::size(16), 14,
                 byte_size(variable_val)::size(16)>> <> variable_val <> <<15>>
             )
  end

  test "more complex offset pdus" do
    variable_val = "This is just a test."
    another_variable_val = "This is also just a test."

    sub_pdu = %TestPdu.SomeSubPdu{
      size_field: byte_size(variable_val),
      variable_field: variable_val
    }

    pdu = %TestPdu.OffsetSubPdu{
      static_field: 78,
      first_sub: sub_pdu,
      second_sub: %TestPdu.SomeSubPdu{
        size_field: byte_size(another_variable_val),
        variable_field: another_variable_val
      }
    }

    assert <<5::size(16), 5 + Exgencode.Pdu.sizeof_pdu(sub_pdu, nil, :bytes)::size(16), 78,
             byte_size(variable_val)::size(16)>> <>
             variable_val <> <<byte_size(another_variable_val)::size(16)>> <> another_variable_val ==
             Exgencode.Pdu.encode(pdu)

    assert {%TestPdu.OffsetSubPdu{
              pdu
              | offset_to_first_sub: 5,
                offset_to_second_sub: 5 + Exgencode.Pdu.sizeof_pdu(sub_pdu, nil, :bytes)
            },
            <<>>} ==
             Exgencode.Pdu.decode(
               %TestPdu.OffsetSubPdu{},
               <<5::size(16), 5 + Exgencode.Pdu.sizeof_pdu(sub_pdu, nil, :bytes)::size(16), 78,
                 byte_size(variable_val)::size(16)>> <>
                 variable_val <>
                 <<byte_size(another_variable_val)::size(16)>> <> another_variable_val
             )
  end

  test "versioned offset pdus" do
    pdu = %TestPdu.VersionedOffsetPdu{
      static_field: 78,
      versioned_field: 10,
      something: 18
    }

    assert <<5::size(16), 78, 10::size(16), 18>> ==
             Exgencode.Pdu.encode(pdu)

    assert <<3::size(16), 78, 18>> ==
             Exgencode.Pdu.encode(pdu, "1.0.0")

    assert {%TestPdu.VersionedOffsetPdu{
              pdu
              | offset_to_something: 5
            },
            <<>>} ==
             Exgencode.Pdu.decode(
               %TestPdu.VersionedOffsetPdu{},
               <<5::size(16), 78, 10::size(16), 18>>
             )

    assert {%TestPdu.VersionedOffsetPdu{
              pdu
              | offset_to_something: 3,
                versioned_field: nil
            },
            <<>>} ==
             Exgencode.Pdu.decode(
               %TestPdu.VersionedOffsetPdu{},
               <<3::size(16), 78, 18>>,
               "1.0.0"
             )
  end
end
