"""Assemble a .TP payload from its four sections."""
from . import meta_codec, mn_encode, ls_parse

HEADER_END = 0x7E


def find_sections(raw):
    """Return (header_end, pos_mark, appl_mark) offsets for a payload."""
    pos_mark = raw.index(b'\xff\xff\x03', HEADER_END)
    appl_mark = raw.index(b'\xff\xff\x04', pos_mark)
    return HEADER_END, pos_mark, appl_mark


def split_sections(raw):
    he, pm, am = find_sections(raw)
    return raw[:he], raw[he:pm], raw[pm:am], raw[am:]


def pos_records(raw):
    """Parse /POS into {position number: record bytes} using u16BE framing."""
    _, pm, am = find_sections(raw)
    p, out = pm + 3, {}
    while p < am:
        ln = int.from_bytes(raw[p:p + 2], 'big')
        rec = raw[p:p + 2 + ln]
        out[int.from_bytes(rec[2:4], 'big')] = rec
        p += 2 + ln
    return out


def mn_section(lines):
    """mn_encode emits <len><body><term>; the payload wants <u16BE len><body>.

    That is the same byte stream shifted by one: prepend the high byte of the
    first record's length and drop the trailing byte, which is really the first
    byte of the /POS marker.
    """
    blob = mn_encode.enc_mn(lines)
    return b'\x00' + blob[:-1]


def ls_mn_lines(path):
    lines = [l.rstrip('\r') for l in
             open(path, encoding='latin-1').read().split('\n')]
    a = lines.index('/MN') + 1
    b = next(i for i, l in enumerate(lines) if l.startswith('/POS'))
    return lines[a:b]


def _key(p):
    return (p.kind, p.uf, p.ut, p.config, tuple(p.vals))


def build_pos(ref_raw, target):
    """Build /POS, reusing reference records so taught float32 values survive.

    Re-encoding a position from .LS text does NOT reproduce the original bytes:
    the text carries only 3 decimals, so every value lands on a neighbouring
    float32. Any position the reference already holds is therefore copied
    verbatim, and a new position is only synthesised by copying one whose
    taught values are identical.
    """
    have = pos_records(ref_raw)
    body = b''
    for p in target.positions:
        if p.num in have:
            body += have[p.num]
            continue
        twin = next((q.num for q in target.positions
                     if q.num in have and _key(q) == _key(p)), None)
        if twin is None:
            raise ValueError(
                'P[%d] is not present in the reference and has no bit-exact '
                'twin there. Encoding it from .LS text would silently shift '
                'the taught position by up to one float32 step.' % p.num)
        rec = bytearray(have[twin])
        rec[2:4] = p.num.to_bytes(2, 'big')
        body += bytes(rec)
    return b'\xff\xff\x03' + body


def build(ref_raw, target_ls, name, comment, file_name, modified):
    """Build a complete .TP payload for target_ls, using ref_raw as the donor
    for position data and for header fields the .LS does not determine."""
    hdr_b, _, _, appl_b = split_sections(ref_raw)
    target = ls_parse.parse(target_ls)
    lines = ls_mn_lines(target_ls)

    h = meta_codec.decode_header(hdr_b)
    h.update(name=name, comment=comment, line_count=len(lines), modified=modified)
    header = meta_codec.encode_header(h)

    recs = meta_codec.decode_appl(appl_b)
    for r in recs:
        if r['body'][:4] == b'LANG':
            r['body'] = b'LANG' + file_name.encode('ascii') + b'\x00\x00'

    return header + mn_section(lines) + build_pos(ref_raw, target) \
        + meta_codec.encode_appl(recs)
