import strformat
import streams
import os

import err
import utils

const BPS_HEADER = "BPS1"
const SOURCE_CHECKSUM_POS = 12
const TARGET_CHECKSUM_POS = 8
const PATCH_CHECKSUM_POS = 4

# Algorithm from official BPS spec
proc decode(s: FileStream): uint64 =
    var shift = 1u64
    while true:
        let x = s.readUint8()
        result += (x and 0x7F) * shift
        if (x and 0x80) != 0:
            break
        shift = shift shl 7
        result += shift

proc sourceRead(src, target: FileStream, offset: var int, length: int) =
    var buffer = newSeq[uint8](length)
    src.setPosition(offset)
    target.setPosition(offset)

    discard src.readData(addr(buffer[0]), length)
    target.writeData(addr(buffer[0]), length)
    offset += length

proc targetRead(patch, target: FileStream, offset: var int, length: int) =
    var buffer = newSeq[uint8](length)
    target.setPosition(offset)

    discard patch.readData(addr(buffer[0]), length)
    target.writeData(addr(buffer[0]), length)
    offset += length

proc sourceCopy(src, patch, target: FileStream, source_offset, output_offset: var int, length: int) =
    var buffer = newSeq[uint8](length)
    let raw = patch.decode()
    let sign = if (raw and 1) != 0: -1 else: 1
    source_offset += sign * int(raw shr 1)

    src.setPosition(source_offset)
    target.setPosition(output_offset)
    discard src.readData(addr(buffer[0]), length)
    target.writeData(addr(buffer[0]), length)

    source_offset += length
    output_offset += length

proc targetCopy(patch, target: FileStream, target_offset, output_offset: var int, length: int) =
    var buffer = newSeq[uint8](length)
    let raw = patch.decode()
    let sign = if (raw and 1) != 0: -1 else: 1
    target_offset += sign * int(raw shr 1)

    target.setPosition(target_offset)
    discard target.readData(addr(buffer[0]), length)

    # It's possible the data could be modified as we write it, need to adjust
    if target_offset < output_offset and output_offset < (target_offset + length):
        let overlap_idx = output_offset - target_offset
        let overlap_size = target_offset + length - output_offset
        for i in 0..<overlap_size:
            buffer[overlap_idx + i] = buffer[i]

    target.setPosition(output_offset)
    target.writeData(addr(buffer[0]), length)

    target_offset += length
    output_offset += length

proc is_bps*(patch: FileStream, length: int): bool =
    let header = patch.readStr(BPS_HEADER.len())
    return header == BPS_HEADER

proc patch_bps*(patch: FileStream, patch_len: int, source_name, output_name: string) =
    patch.setPosition(BPS_HEADER.len())

    let source_len = patch.decode()
    if source_len != uint64(source_name.getFileSize()):
        raise newException(InvalidError, "Source file is the incorrect size.")

    var source = newFileStream(source_name, FileMode.fmRead)

    # Jump to end to check source and patch checksums
    let return_idx = patch.getPosition()
    patch.setPosition(patch_len - SOURCE_CHECKSUM_POS)
    let source_checksum = patch.readUint32()
    patch.setPosition(patch_len - PATCH_CHECKSUM_POS)
    let patch_checksum = patch.readUint32()

    let actual_source_checksum = crc32(source, 0, int(source_len))
    if source_checksum != actual_source_checksum:
        echo(&"Expected checksum: {source_checksum}, actual checksum: {actual_source_checksum}")
        raise newException(InvalidError, "Source file has incorrect checksum")

    let actual_patch_checksum = crc32(patch, 0, patch_len - PATCH_CHECKSUM_POS) # Don't include 32-bit checksum value itself
    if patch_checksum != actual_patch_checksum:
        echo(&"Expected checksum: {patch_checksum}, actual checksum: {actual_patch_checksum}")
        raise newException(InvalidError, "Patch file has invalid checksum")


    patch.setPosition(return_idx)
    let target_len = patch.decode()
    let metadata_len = patch.decode()

    var metadata: string
    if metadata_len > 0:
        patch.readStr(int(metadata_len), metadata)
        echo(&"Metadata: {metadata}")

    var target = newFileStream(output_name, FileMode.fmReadWrite)
    var output_offset, source_rel_offset, target_rel_offset = 0

    while true:
        let idx = patch.getPosition()
        if idx == patch_len - SOURCE_CHECKSUM_POS:
            break

        let data = patch.decode()
        let command = data and 3
        let length = int(data shr 2) + 1

        case command:
            of 0: sourceRead(source, target, output_offset, length)
            of 1: targetRead(patch, target, output_offset, length)
            of 2: sourceCopy(source, patch, target, source_rel_offset, output_offset, length)
            of 3: targetCopy(patch, target, target_rel_offset, output_offset, length)
            else: assert(true, "Unreachable")

    target.flush()

    let output_length = int(output_name.getFileSize())
    if output_length != int(target_len):
        echo(&"Expected size: {target_len}, actual size: {output_length}")
        raise newException(CorruptionError, "Output file is not of correct size")

    patch.setPosition(patch_len - TARGET_CHECKSUM_POS)
    let target_checksum = patch.readUint32()
    let actual_target_checksum = crc32(target, 0, int(target_len))
    if target_checksum != actual_target_checksum:
        echo(&"Expected checksum: {target_checksum}, actual checksum: {actual_target_checksum}")
        raise newException(CorruptionError, "Output file has incorrect checksum")

    source.close()
    target.close()
