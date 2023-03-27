proc pack*(data: seq[char]): int =
    result = 0
    for v in data:
        result = result shl 8
        result = result or cast[int](v)
