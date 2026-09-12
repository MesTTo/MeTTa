The ZIP fixtures have fixed timestamps of 2000-01-01 and Unix file kinds.
`compression-data.zip` contains `./`, `sub/`, `sub/bytes.bin` with bytes
0, 128, 255 and 10, and an empty regular file named `empty`.
`compression-unsafe.zip` contains `../escape` with byte 42. Reading its data
is harmless; extraction must refuse its parent path before publication.
`compression-unicode.zip` contains `café/π🙂` with bytes 0, 128 and 255. Its
UTF8 name flag and payload form the independent native locale reproduction.
`compression-legacy.zip` contains CP437 `café` with bytes 0, 128 and 255. It
was written as ASCII `caf_` and both equal-length header names changed to
`caf\x82`; offsets, CRC and the unset UTF8 flag remain intact.
`compression-unicode-extra.zip` adds a version1 Unicode path extra field naming
`café/π🙂`, with the CRC of the original `caf\x82` header bytes.
