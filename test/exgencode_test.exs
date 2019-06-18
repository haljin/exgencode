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
end
