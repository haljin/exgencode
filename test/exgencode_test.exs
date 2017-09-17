defmodule ExgencodeTest do
  use ExUnit.Case
  alias Exgencode.TestPdu
  doctest Exgencode.Pdu


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
    assert << 1 :: size(12), 100 :: size(24), 15 :: size(8), 10 :: size(24)>> == Exgencode.Pdu.encode(pdu)
  end

  test "decoding" do
    pdu = %TestPdu.PzTestMsg{otherTestField: 100}
    binary = << 1 :: size(12), 100 :: size(24), 15 :: size(8), 10 :: size(24)>>
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.PzTestMsg{}, binary)
  end
  
  test "incorrect constant fails" do
    pdu = %TestPdu.PzTestMsg{otherTestField: 100}
    binary = << 1 :: size(12), 100 :: size(24), 15 :: size(8), 99 :: size(24)>>
    assert_raise FunctionClauseError, fn ->  {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.PzTestMsg{}, binary) end
  end

  test "custom encode" do
    pdu = %TestPdu.CustomEncodeMsg{randomField: 0}
    assert << 0 :: size(1), 6 :: size(7) >> == Exgencode.Pdu.encode(pdu)
  end

  test "custom decode" do
    pdu = %TestPdu.CustomEncodeMsg{randomField: 0, customField: 6}
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.CustomEncodeMsg{}, << 0 :: size(1), 6 :: size(7) >>)
  end

  test "encode/decode symmetry" do
    pdu = %TestPdu.PzTestMsg{otherTestField: 100}
    customPdu = %TestPdu.CustomEncodeMsg{randomField: 0, customField: 6}
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.PzTestMsg{}, Exgencode.Pdu.encode(pdu))
    assert {^customPdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.CustomEncodeMsg{}, Exgencode.Pdu.encode(customPdu))
  end

  test "versioning encode" do
    pdu = %TestPdu.VersionedMsg{newerField: 111, evenNewerField: 7}
    assert << 10 :: size(16), 111 :: size(8), 14 :: size(8) >> == Exgencode.Pdu.encode(pdu)
    assert << 10 :: size(16) >> == Exgencode.Pdu.encode(pdu, "1.0.0")
    assert << 10 :: size(16), 111 :: size(8) >> == Exgencode.Pdu.encode(pdu, "2.0.0")
    assert << 10 :: size(16), 111 :: size(8), 14 :: size(8) >> == Exgencode.Pdu.encode(pdu, "2.1.0")
  end

  test "versioning decode" do
    pdu = %TestPdu.VersionedMsg{}
    binary = << 10 :: size(16) >>
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, binary, "1.0.0")

    pdu = %TestPdu.VersionedMsg{newerField: 111}
    binary = << 10 :: size(16), 111 :: size(8) >>
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, binary, "2.0.0")

    pdu = %TestPdu.VersionedMsg{newerField: 111, evenNewerField: 7}
    binary = << 10 :: size(16), 111 :: size(8), 14 :: size(8) >>
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, binary)
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, binary, "2.1.0")

    assert {%TestPdu.VersionedMsg{}, << 111 :: size(8), 14 :: size(8) >>} = Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, binary, "1.0.0")
  end
  
  test "versioned encode/decode symmetry" do
    pdu = %TestPdu.VersionedMsg{}
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, Exgencode.Pdu.encode(pdu, "1.0.0"), "1.0.0")

    pdu = %TestPdu.VersionedMsg{newerField: 111}
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, Exgencode.Pdu.encode(pdu, "2.0.0"), "2.0.0")
    
    pdu = %TestPdu.VersionedMsg{newerField: 111, evenNewerField: 7}
    assert {^pdu, <<>>} = Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, Exgencode.Pdu.encode(pdu, "2.1.0"), "2.1.0")
  end
end
