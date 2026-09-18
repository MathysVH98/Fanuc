#!/usr/bin/env python3
"""Convert a FANUC .LS listing to a binary .TP program.

Position data cannot be recovered from .LS text alone: the listing prints only
three decimals, so re-encoding shifts every taught value onto a neighbouring
float32. A reference .TP holding the same points is therefore required, and its
position records are copied verbatim.

  ls2tp.py TARGET.LS --reference REF.TP --out TARGET.TP \
           [--name N] [--comment C] [--file-name F] [--modified YY-MM-DD HH:MM:SS]

Defaults for name / comment / file-name / modified are read from the target's
own /ATTR block.
"""
import argparse, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tp_tools import build, container, ls_parse


def parse_attr_dt(s):
    m = re.match(r'DATE\s+(\d+)-(\d+)-(\d+)\s+TIME\s+(\d+):(\d+):(\d+)', s.strip())
    if not m:
        raise ValueError('unrecognised date/time: %r' % s)
    y, mo, d, hh, mm, ss = (int(x) for x in m.groups())
    return dict(year=2000 + y, month=mo, day=d, hour=hh, minute=mm, second=ss)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('target_ls')
    ap.add_argument('--reference', required=True, help='a .TP holding the same positions')
    ap.add_argument('--out', required=True)
    ap.add_argument('--name'); ap.add_argument('--comment')
    ap.add_argument('--file-name'); ap.add_argument('--modified')
    a = ap.parse_args(argv)

    prog = ls_parse.parse(a.target_ls)
    ref, _ = container.decompress(open(a.reference, 'rb').read())

    payload = build.build(
        ref, a.target_ls,
        name=a.name or prog.name,
        comment=a.comment or prog.attr.get('COMMENT', '').strip('"'),
        file_name=a.file_name or prog.attr.get('FILE_NAME', prog.name),
        modified=parse_attr_dt(a.modified) if a.modified
        else parse_attr_dt(prog.attr['MODIFIED']))

    tp = container.compress(payload)
    open(a.out, 'wb').write(tp)
    print('wrote %s  (%d bytes, payload %d)' % (a.out, len(tp), len(payload)))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
