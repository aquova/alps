import streams

const CRC32_MAGIC = 0xEDB88320u32

proc readUintX*(s: FileStream, bytes: int): int =
    result = 0
    var buffer = newSeq[uint8](bytes)
    discard s.readData(addr(buffer[0]), bytes)
    for b in buffer:
        result = result shl 8
        result = result or int(b)

# Algorithm from here: https://rosettacode.org/wiki/CRC-32#Nim
proc initCrc32Table(): array[0..255, uint32] =
    for i in countup(0, 255):
        var v = uint32(i)
        for j in countup(0, 7):
            if (v and 1) > 0:
                v = (v shr 1) xor CRC32_MAGIC
            else:
                v = v shr 1
        result[i] = v

const crc32_table = initCrc32Table()
proc crc32*(s: FileStream, start, length: int): uint32 =
    s.setPosition(start)
    result = 0xFFFFFFFFu32
    for _ in countup(1, length):
        let d = s.readUint8()
        let idx = (result and 0xFF) xor uint32(d)
        result = (result shr 8) xor crc32_table[idx]
    result = not result
