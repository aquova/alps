import streams

proc readUintX*(s: FileStream, bytes: int): int =
    result = 0
    var buffer = newSeq[uint8](bytes)
    discard s.readData(addr(buffer[0]), bytes)
    for b in buffer:
        result = result shl 8
        result = result or int(b)
