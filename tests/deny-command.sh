#!/bin/sh
printf 'Unstubbed external command refused: %s %s\n' "${0##*/}" "$*" >&2
exit 97
