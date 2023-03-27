# alps
# Another Lightweight Patching Suite

import os
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

    var source_f, patch_f, output_f: File

    if not source_f.open(source_filename):
        echo("Source file does not exist")
        quit(1)
    var source = source_f.readall()
    source_f.close()

    if not patch_f.open(patch_filename):
        echo("Patch file does not exist")
        quit(1)
    var patch = patch_f.readall()
    patch_f.close()

    if is_ips(patch):
        try:
            patch_ips(patch, source)
        except Exception as e:
            echo("Error! ", e.msg)
            quit(2)

        let success = output_f.open(output_filename, FileMode.fmWrite)
        if not success:
            echo("Unable to open ", output_filename)
            quit(1)

        output_f.write(source)
        output_f.close()
    else:
        echo("I was not able to identify the patch file")

when isMainModule:
    main()

