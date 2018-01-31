defmodule Exgencode.Pdu do
  @moduledoc """
  The module contains functions for operating with PDUs defined with the `defpdu/2` macro.


  """

  @doc "Returns the size of the field in bits."
  @spec sizeof(Exgencode.pdu, atom) :: non_neg_integer
  def sizeof(pdu, fieldName), do: Exgencode.Pdu.Protocol.sizeof(pdu, fieldName)

  @doc """
  Encode the Elixir structure into a binary give the protocol version.
  
  ### Examples:
      iex> Exgencode.Pdu.encode(%TestPdu.PzTestMsg{otherTestField: 100})
      << 1 :: size(12), 100 :: size(24), 15 :: size(8), 10 :: size(24) >>

      iex> Exgencode.Pdu.encode(%TestPdu.PzTestMsg{testField: 99, otherTestField: 100})
      << 99 :: size(12), 100 :: size(24), 15 :: size(8), 10 :: size(24) >>

  Version number can be optionally added to control the encoding of the PDU and exclude certain fields if the version number is lower that specified.
  
      pdu = %TestPdu.VersionedMsg{newerField: 111, evenNewerField: 7}
      assert << 10 :: size(16), 111 :: size(8), 14 :: size(8) >> == Exgencode.Pdu.encode(pdu)
      assert << 10 :: size(16) >> == Exgencode.Pdu.encode(pdu, "1.0.0")
      assert << 10 :: size(16), 111 :: size(8) >> == Exgencode.Pdu.encode(pdu, "2.0.0")

  ### Examples:

      iex> Exgencode.Pdu.encode(%TestPdu.VersionedMsg{newerField: 111, evenNewerField: 7}, "1.0.0")
      << 10 :: size(16) >>

      iex> Exgencode.Pdu.encode(%TestPdu.VersionedMsg{newerField: 111, evenNewerField: 7}, "2.0.0")
      << 10 :: size(16), 111 :: size(8) >>
  """
  @spec encode(Exgencode.pdu, nil | Version.version) :: binary
  def encode(pdu, version \\ nil), do: Exgencode.Pdu.Protocol.encode(pdu, version)

  @doc """
  Decode a binary into the specified Elixir structure.

  Returns the given structure with fields filled out and the remainder binary. The remainder should be an empty binary and leftovers usually indicate
  a mangled binary.
  
  ### Examples:
      iex> Exgencode.Pdu.decode(%TestPdu.PzTestMsg{}, << 1 :: size(12), 100 :: size(24), 15 :: size(8), 10 :: size(24)>>)
      {%TestPdu.PzTestMsg{otherTestField: 100}, <<>>}

  Version number can be optionally added to control how the decoding function reads the given binary. If the provided version does not match the requirement
  specified in the field definition the given field will be ignored.
  
  ### Examples:
      iex> Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, << 10 :: size(16) >>, "1.0.0")
      {%TestPdu.VersionedMsg{oldField: 10}, <<>>}

      iex> Exgencode.Pdu.decode(%TestPdu.VersionedMsg{}, << 10 :: size(16), 111 :: size(8) >>, "2.0.0")
      {%TestPdu.VersionedMsg{oldField: 10, newerField: 111}, <<>>} 

  """
  @spec decode(Exgencode.pdu, binary, nil | Version.version) :: {Exgencode.pdu, binary}
  def decode(pdu, binary, version \\ nil), do: Exgencode.Pdu.Protocol.decode(pdu, binary, version)
    
end
