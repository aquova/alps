# alps
# Another Lightweight Patching Suite

import streams
import os

import bps
import err
import ips

proc usage() =
    echo """
ALPS - Another Lightweight Patching Suite
Usage: alps SOURCE PATCH OUTPUT
    """

proc main() =
    if paramCount() < 3:
        usage()
        quit(0)

    let source_filename = paramStr(1)
    let patch_filename = paramStr(2)
    let output_filename = paramStr(3)

    var patch = newFileStream(patch_filename, FileMode.fmRead)
    let patch_size = int(patch_filename.getFileSize())

    if patch.isNil():
        raise newException(IOError, "Unable to open patch file")

    if is_ips(patch, patch_size):
        try:
            patch_ips(patch, patch_size, source_filename, output_filename)
        except Exception as e:
            echo("Error! ", e.msg)
            quit(2)
    elif is_bps(patch, patch_size):
        try:
            patch_bps(patch, patch_size, source_filename, output_filename)
        except CorruptionError as e:
            echo(e.msg)
            if output_filename.fileExists():
                output_filename.removeFile()
    else:
        echo("I was not able to identify the patch file")

    patch.close()

when isMainModule:
    main()

