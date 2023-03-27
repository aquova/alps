import err
import utils

const OFFSET_LEN = 3
const SIZE_LEN = 2
const IPS_HEADER = @['P', 'A', 'T', 'C', 'H']
const IPS_FOOTER = @['E', 'O', 'F']

proc is_ips*(patch: openarray[char]): bool =
    let header_match = patch[0..<IPS_HEADER.len()] == IPS_HEADER
    let footer_match = patch[^IPS_FOOTER.len()..^1] == IPS_FOOTER
    return header_match and footer_match

proc patch_ips*(patch: openarray[char], output: var openarray[char]) {.raises: [CorruptionError].}=
    var idx = IPS_HEADER.len()
    let footer_offset = patch.len() - IPS_FOOTER.len()
    while true:
        if idx == footer_offset:
            break
        elif idx > footer_offset:
            raise newException(CorruptionError, "End of file was overrun")

        let offset = pack(patch[idx..<(idx + OFFSET_LEN)])
        idx += OFFSET_LEN
        var size = pack(patch[idx..<(idx + SIZE_LEN)])
        idx += SIZE_LEN

        var rle = false
        if size == 0:
            rle = true
            size = pack(patch[idx..<(idx + SIZE_LEN)])
            idx += SIZE_LEN

        if offset + size > output.len():
            raise newException(CorruptionError, "This patch file is corrupted")

        if rle:
            let data = patch[idx]
            for i in countup(0, size - 1):
                output[offset + i] = data
            inc(idx)
        else:
            for i in countup(0, size - 1):
                output[offset + i] = patch[idx + i]
            idx += size

