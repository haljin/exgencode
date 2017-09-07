defmodule TestPdu do
  require Exgencode
  import Exgencode

  defpdu MsgSubSection,
    someField: [default: 15, size: 8]

  defpdu PzTestMsg, 
    testField: [default: 1, size: 12], 
    otherTestField: [size: 24],
    subSection: [default: %MsgSubSection{}, size: :subrecord],
    constField: [default: 10, size: 24, constant: true]
  
  defpdu CustomEncodeMsg,
    randomField: [size: 1],
    customField: [encode: fn(_) -> << 6 :: size(7) >> end, 
                  decode: fn(pdu, << _ :: size(7), rest :: bitstring>>) -> {Map.replace(pdu, :customField, 6), rest} end]
  

  


end