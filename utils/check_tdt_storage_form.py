#!/usr/bin/env python3
"""
Checks the trade-data-tool launch form offers no S3 storage on Onyxia.

S3 mode can't work on the UN Global Platform (the platform's storage serves
files only to services running on it), so the form must not offer it:
- objectStorage.provider is hidden and defaults to minio;
- no field reads Onyxia's s3 context ({{s3.*}}). Onyxia treats any such read
  as "this chart uses S3" and injects the user's S3 credentials into the
  release values.
"""

import argparse
import json
import re
import sys
from pathlib import Path

SCHEMA = Path('charts/trade-data-tool/values.schema.json')
# Onyxia resolves "{{s3.x}}", "prefix-{{s3.x}}" and a bare top-level "s3.x" alike.
S3_REF = re.compile(r'(\{\{\s*|^\s*)s3(\.|\[|\s*\}\}|\s*$)')


def onyxia_expressions(node):
    if isinstance(node, dict):
        for key in ('overwriteDefaultWith', 'overwriteListEnumWith'):
            if key in node.get('x-onyxia', {}):
                yield from strings(node['x-onyxia'][key])
        for value in node.values():
            yield from onyxia_expressions(value)
    elif isinstance(node, list):
        for value in node:
            yield from onyxia_expressions(value)


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from strings(v)


def problems(schema_text: str) -> list[str]:
    found = []
    schema = json.loads(schema_text)
    provider = schema['properties']['objectStorage']['properties']['provider']
    if provider.get('x-onyxia', {}).get('hidden') is not True:
        found.append('objectStorage.provider must be hidden on the Onyxia form (x-onyxia.hidden: true)')
    if provider.get('default') != 'minio':
        found.append('objectStorage.provider must default to minio')
    for expression in onyxia_expressions(schema):
        if S3_REF.search(expression):
            found.append(f'{expression!r} reads Onyxia\'s s3 context: Onyxia would inject S3 credentials')
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('schema', nargs='?', default=str(SCHEMA))
    args = parser.parse_args()
    found = problems(Path(args.schema).read_text())
    for p in found:
        print(f'{args.schema}: {p}', file=sys.stderr)
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
