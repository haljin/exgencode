defmodule ExgencodeTest do
  use ExUnit.Case

  alias Exgencode.TestPdu


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
end
