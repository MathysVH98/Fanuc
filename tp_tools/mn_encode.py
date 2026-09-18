#!/usr/bin/env python3
"""Encode FANUC .LS /MN program lines back into the binary /MN record stream.

Inverse of mn_decode.py.  See MN_SPEC.md.

Usage: python3 mn_encode.py PG21.LS            # prints round-trip report
"""
import re, struct, sys

# type byte for each variable class (same table as the decoder)
VAR_TYPE = {'R': 0x03, 'PR': 0x04, 'DI': 0x0A, 'DO': 0x0F, 'GO': 0x17,
            'LBL': 0x7F, 'RI': 0x11, 'AI': 0x13}
ENUM_VAL = {'OFF': 0x00, 'ON': 0x01, 'LPOS': 0x07}
MTYPE   = {'J': 0x01, 'L': 0x02, 'C': 0x03, 'A': 0x07}
POSTYPE = {'P': 0x00, 'PR': 0x01}
SPDUNIT = {'%': 0x00, 'mm/sec': 0x01, 'cm/min': 0x02, 'inch/min': 0x03,
           'deg/sec': 0x04, 'sec': 0x05, 'msec': 0x06}
# macro/instruction-table ids -- program specific (read off this controller)
MACRO_ID = {'ENTER ZONE': 3, 'EXIT ZONE': 4,
            'GO TO HOME POS': 5, 'GO TO POUNCE': 6}

def u16(v):  return struct.pack('>H', v)

# ---------------------------------------------------------------- operands ---
def enc_const(txt):
    if txt.startswith('(') and txt.endswith(')'):
        txt = txt[1:-1]
    if '.' in txt:
        return b'\x01\x03' + struct.pack('>f', float(txt))
    v = int(txt)
    if -128 <= v <= 127:
        return b'\x01\x01' + struct.pack('>b', v)
    return b'\x01\x02' + struct.pack('>i', v)

def enc_operand(txt):
    txt = txt.strip()
    if txt in ENUM_VAL:
        return bytes([0x32, ENUM_VAL[txt]])
    m = re.fullmatch(r'([A-Z]+)\[(\*?)(\d+)(?:,(\d+))?\]', txt)
    if m:
        name, star, idx, el = m.group(1), m.group(2), int(m.group(3)), m.group(4)
        n = idx | (0x8000 if star else 0)
        out = bytes([VAR_TYPE[name], 0x02]) + u16(n)
        if el is not None:
            out += b'\x02' + u16(int(el))
        return out
    return enc_const(txt)

def split_expr(s):
    """['PR[10,3]', '+R[1]', '-177']  -> keeps the operator with each term"""
    out, depth, start = [], 0, 0
    for i, c in enumerate(s):
        if c in '[(':
            depth += 1
        elif c in '])':
            depth -= 1
        elif depth == 0 and c in '+-' and i > start:
            out.append(s[start:i]); start = i
    out.append(s[start:])
    return out

def enc_expr(s):
    out = b''
    for i, term in enumerate(split_expr(s)):
        if i:
            out += bytes([0x65 if term[0] == '+' else 0x66])
            term = term[1:]
        out += enc_operand(term)
    return out

def enc_condition(s):
    out = b''
    for i, part in enumerate(re.split(r' (AND|OR) ', s)):
        if i % 2 == 1:
            out += bytes([0x71 if part == 'AND' else 0x72]); continue
        lhs, rhs = part.split('=', 1)
        out += enc_operand(lhs) + b'\x6b' + enc_operand(rhs)
    return out

# ------------------------------------------------------------- instructions ---
RE_MOTION = re.compile(r'([JLCA]) (P|PR)\[(\d+|\.\.\.)\] (\d+)'
                       r'(%|mm/sec|cm/min|inch/min|deg/sec|sec|msec) '
                       r'(FINE|CNT(\d+))$')

def enc_stmt(s):
    if s == '':
        return b'\xff'
    if s.startswith('//'):
        return b'\x48' + enc_stmt(s[2:])
    if s.startswith('!'):                       # remark: text kept verbatim
        return b'\x1e' + s[1:].encode('latin-1') + b'\x00'
    s = s.rstrip(' ')                           # drop the field-padding spaces

    m = RE_MOTION.fullmatch(s)
    if m:
        pos = 0 if m.group(3) == '...' else int(m.group(3))
        term, tval = (0x00, 0) if m.group(6) == 'FINE' else (0x80, int(m.group(7)))
        return (bytes([0xFE, MTYPE[m.group(1)], POSTYPE[m.group(2)]]) + u16(pos) +
                u16(int(m.group(4))) + bytes([SPDUNIT[m.group(5)], term, tval]))

    if s.startswith('JMP '):
        return b'\x7e' + enc_operand(s[4:])

    if s.startswith('IF '):
        cond, action = s[3:].split(',', 1)
        return b'\x78' + enc_condition(cond) + enc_stmt(action)

    m = re.fullmatch(r'WAIT +([\d.]+)\(sec\)', s)
    if m:
        return b'\x7b\x02' + u16(int(round(float(m.group(1)) * 100)))
    if s.startswith('WAIT '):
        return b'\x7c' + enc_condition(s[5:])

    m = re.fullmatch(r'LBL\[(\*?)(\d+)(?::(.*))?\]', s)
    if m:
        n = int(m.group(2)) | (0x8000 if m.group(1) else 0)
        name = (m.group(3) or '').encode('latin-1')
        return b'\x80\x02' + u16(n) + name + b'\x00'

    if s.startswith('CALL '):
        return b'\x81\x82' + s[5:].encode('latin-1') + b'\x00'

    m = re.fullmatch(r'PAYLOAD\[(\d+)\]', s)
    if m:
        return b'\x95\x01\x00\x02' + u16(int(m.group(1)))

    m = re.fullmatch(r'([A-Z][A-Z0-9_ ]*)\((.*)\)', s)          # macro with args
    if m and m.group(1) in MACRO_ID:
        args = m.group(2).split(',')
        out = bytes([0x87, MACRO_ID[m.group(1)]]) + m.group(1).encode() + b'\x00'
        out += bytes([0x3D, len(args)])
        for a in args:
            out += enc_operand(a)
        return out + b'\x40'
    if s in MACRO_ID:                                            # macro, no args
        return bytes([0x87, MACRO_ID[s]]) + s.encode() + b'\x00'

    m = re.fullmatch(r'([A-Z]+\[[^\]]*\])=(.*)', s)              # assignment
    if m:
        return enc_operand(m.group(1)) + b'\x64' + enc_expr(m.group(2))

    raise ValueError('cannot encode: %r' % s)

# ----------------------------------------------------------------- records ---
def enc_line(line, term=0x00):
    """line = one full .LS /MN line, without the CR/LF.  Returns record bytes."""
    assert line[4] == ':', line
    s = line[5:]
    assert s.endswith(' ;'), repr(line)
    s = s[:-2]
    if s.startswith('  '):            # everything except un-commented motion
        s = s[2:]
    body = enc_stmt(s)
    return bytes([len(body)]) + body + bytes([term])

def enc_mn(lines):
    out = b''
    for i, l in enumerate(lines):
        out += enc_line(l, 0xFF if i == len(lines) - 1 else 0x00)
    return out

# -------------------------------------------------------------------- main ---
if __name__ == '__main__':
    ls  = sys.argv[1] if len(sys.argv) > 1 else 'PG21.LS'
    raw = open(sys.argv[2] if len(sys.argv) > 2 else 'PG21.tp.raw0', 'rb').read()
    lines = [l.rstrip('\r') for l in
             open(ls, encoding='latin-1').read().split('\n')[33:583]]
    ref = raw[0x7F:0x1E97]
    got = enc_mn(lines)
    print('reference bytes: %d   encoded bytes: %d' % (len(ref), len(got)))

    # per-record comparison
    def records(buf):
        p, r = 0, []
        while p < len(buf):
            ln = buf[p]; r.append(buf[p:p+ln+2]); p += ln + 2
        return r
    a, b = records(ref), records(got)
    bad = [i for i in range(min(len(a), len(b))) if a[i] != b[i]]
    print('records: %d ref / %d encoded' % (len(a), len(b)))
    print('MISMATCHING RECORDS: %d' % len(bad))
    for i in bad:
        print('  line %d: %s' % (i + 1, lines[i]))
        print('    ref: %s' % a[i].hex(' '))
        print('    got: %s' % b[i].hex(' '))
    print('whole-block identical:', ref == got)
