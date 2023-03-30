import streams
import os

import err
import utils

const OFFSET_LEN = 3
const SIZE_LEN = 2
const IPS_HEADER = "PATCH"
const IPS_FOOTER = "EOF"
const BUFFER_SIZE = 0xFFFF

proc is_ips*(patch: FileStream, length: int): bool =
    let header = patch.readStr(IPS_HEADER.len())
    patch.setPosition(length - IPS_FOOTER.len())
    let footer = patch.readStr(IPS_FOOTER.len())
    patch.setPosition(0)
    return header == IPS_HEADER and footer == IPS_FOOTER

proc patch_ips*(patch: FileStream, patch_len: int, source_name, output_name: string) =
    if not source_name.fileExists():
        raise newException(IOError, "Source file does not exist")

    # TODO: May need to check for directory permissions?
    copyFile(source_name, output_name)
    var output = open(output_name, FileMode.fmReadWriteExisting)
    let source_len = int(source_name.getFileSize())
    var buffer: array[BUFFER_SIZE, uint8]

    patch.setPosition(IPS_HEADER.len())
    let footer_offset = patch_len - IPS_FOOTER.len()
    while true:
        let idx = patch.getPosition()
        if idx == footer_offset:
            break
        elif idx > footer_offset:
            raise newException(CorruptionError, "End of file was overrun")

        let offset = patch.readUintX(OFFSET_LEN)
        var size = patch.readUintX(SIZE_LEN)

        var rle = false
        if size == 0:
            rle = true
            size = patch.readUintX(SIZE_LEN)

        if offset + size > source_len:
            raise newException(CorruptionError, "This patch file is corrupted")

        output.setFilePos(offset)
        if rle:
            let data = patch.readUint8()
            for i in 0..<size:
                buffer[i] = data
            discard output.writeBytes(buffer, 0, size)
        else:
            discard patch.readData(addr(buffer), size)
            discard output.writeBytes(buffer, 0, size)

    output.close()

