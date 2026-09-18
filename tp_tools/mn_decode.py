#!/usr/bin/env python3
"""Decode the /MN section of a FANUC TP binary (decompressed form) to .LS text.

Usage:  python3 mn_decode.py PG21.tp.raw0 [start_hex end_hex]
Emits the 550 /MN program lines (as they appear in PG21.LS lines 34..583).

IMPORTANT: the input must be decompressed with the LZSS ring buffer prefilled
with 0x00 (not 0x20).  See MN_SPEC.md section 0.
"""
import struct, sys

MN_START = 0x7F
MN_END   = 0x1E97

# ---------------------------------------------------------------- framing ---
def split_records(raw, start=MN_START, end=MN_END):
    """Yield (offset, body, pad).  Record = <u8 len><body[len]><u8 pad>."""
    p = start
    out = []
    while p < end:
        ln = raw[p]
        out.append((p, raw[p+1:p+1+ln], raw[p+1+ln]))
        p += ln + 2
    assert p == end, hex(p)
    return out

# --------------------------------------------------------------- operands ---
VAR_NAME = {0x03: 'R', 0x04: 'PR', 0x0A: 'DI', 0x0F: 'DO', 0x17: 'GO',
            0x7F: 'LBL', 0x11: 'RI', 0x13: 'AI'}
ENUM = {0x00: 'OFF', 0x01: 'ON', 0x07: 'LPOS'}

def fmt_float(f):
    """FANUC prints reals truncated (not rounded) to 3 decimals, zeros stripped."""
    neg = f < 0
    m = int(abs(f) * 1000 + 1e-6)          # truncate toward zero
    s = '%d.%03d' % (m // 1000, m % 1000)
    s = s.rstrip('0').rstrip('.')
    return ('-' + s) if neg else s

def fmt_const(v):
    """A negative constant is printed in parentheses."""
    s = fmt_float(v) if isinstance(v, float) else str(v)
    return '(%s)' % s if s.startswith('-') else s

class P:
    def __init__(self, b, i=0):
        self.b, self.i = b, i
    def u8(self):
        v = self.b[self.i]; self.i += 1; return v
    def peek(self):
        return self.b[self.i] if self.i < len(self.b) else None
    def u16(self):
        v = struct.unpack('>H', self.b[self.i:self.i+2])[0]; self.i += 2; return v
    def cstr(self):
        j = self.b.index(0, self.i)
        s = self.b[self.i:j].decode('latin-1'); self.i = j + 1; return s

    def operand(self, typ=None):
        """Parse one operand.  Returns (kind, text, value)."""
        if typ is None:
            typ = self.u8()
        if typ == 0x01:                      # literal constant
            fmt = self.u8()
            if fmt == 0x01:
                v = struct.unpack('>b', self.b[self.i:self.i+1])[0]; self.i += 1
            elif fmt == 0x02:
                v = struct.unpack('>i', self.b[self.i:self.i+4])[0]; self.i += 4
            elif fmt == 0x03:
                v = struct.unpack('>f', self.b[self.i:self.i+4])[0]; self.i += 4
            else:
                raise ValueError('const fmt %02X' % fmt)
            return ('const', fmt_const(v), v)
        if typ == 0x32:                      # small enumerated value
            v = self.u8()
            return ('enum', ENUM.get(v, 'E%d' % v), v)
        if typ in VAR_NAME:
            assert self.u8() == 0x02
            idx = self.u16()
            if typ == 0x04 and self.peek() == 0x02:      # PR[i,j]
                self.u8()
                el = self.u16()
                return ('var', 'PR[%d,%d]' % (idx, el), (idx, el))
            if typ == 0x7F:
                return ('lbl', 'LBL[%s%d]' % ('*' if idx & 0x8000 else '',
                                              idx & 0x7FFF), idx)
            return ('var', '%s[%d]' % (VAR_NAME[typ], idx), idx)
        raise ValueError('operand type %02X @%d' % (typ, self.i))

BINOP = {0x65: '+', 0x66: '-', 0x6B: '=', 0x64: '='}

def rhs_expr(p):
    """operand [ (+|-) operand ]*"""
    s = p.operand()[1]
    while p.peek() in (0x65, 0x66):
        s += BINOP[p.u8()] + p.operand()[1]
    return s

def condition(p):
    """<operand> = <operand>  joined by AND(0x71) / OR(0x72)"""
    parts = [p.operand()[1]]
    assert p.u8() == 0x6B
    parts.append('=' + p.operand()[1])
    s = ''.join(parts)
    while p.peek() in (0x71, 0x72):
        j = p.u8()
        s += (' AND ' if j == 0x71 else ' OR ')
        s += p.operand()[1]
        assert p.u8() == 0x6B
        s += '=' + p.operand()[1]
    return s

# ------------------------------------------------------------ instructions ---
MTYPE  = {0x01: 'J', 0x02: 'L', 0x03: 'C', 0x07: 'A'}
POSTYPE = {0x00: 'P', 0x01: 'PR'}
SPDUNIT = {0x00: '%', 0x01: 'mm/sec', 0x02: 'cm/min', 0x03: 'inch/min',
           0x04: 'deg/sec', 0x05: 'sec', 0x06: 'msec'}

def decode_body(body):
    """Return (text, extra_trailing_spaces, is_motion)."""
    op = body[0]
    p = P(body, 1)

    if op == 0xFF:                                        # blank program line
        assert len(body) == 1
        return '', 0, False

    if op == 0x1E:                                        # ! remark
        return '!' + p.cstr(), 0, False

    if op == 0x48:                                        # //  commented out
        t, x, m = decode_body(body[1:])
        return '//' + t, x, m

    if op == 0xFE:                                        # motion
        mt, pt = p.u8(), p.u8()
        pos, spd = p.u16(), p.u16()
        unit, term, tval = p.u8(), p.u8(), p.u8()
        posn = '...' if pos == 0 else str(pos)
        t = '%s %s[%s] %d%s %s' % (
            MTYPE[mt], POSTYPE[pt], posn, spd, SPDUNIT[unit],
            'FINE' if term == 0x00 else 'CNT%d' % tval)
        return t, 3, True

    if op == 0x7E:                                        # JMP LBL[n]
        return 'JMP ' + p.operand()[1], 0, False

    if op == 0x78:                                        # IF <cond>,<action>
        c = condition(p)
        act, _, _ = decode_body(body[p.i:])
        return 'IF %s,%s' % (c, act), 0, False

    if op == 0x7C:                                        # WAIT <cond>
        return 'WAIT ' + condition(p), 3, False

    if op == 0x7B:                                        # WAIT <t>(sec)
        assert p.u8() == 0x02
        return 'WAIT   %.2f(sec)' % (p.u16() / 100.0), 0, False

    if op == 0x80:                                        # LBL[n] / LBL[n:txt]
        assert p.u8() == 0x02
        num = p.u16()
        name = p.cstr()
        star = '*' if num & 0x8000 else ''
        num &= 0x7FFF
        return ('LBL[%s%d%s]' % (star, num, (':' + name) if name else '')), 0, False

    if op == 0x81:                                        # CALL <prog>
        assert p.u8() == 0x82
        return 'CALL ' + p.cstr(), 3, False

    if op == 0x87:                                        # macro / KAREL call
        p.u8()                                            # macro id
        name = p.cstr()
        if p.peek() == 0x3D:                              # argument list
            p.u8()
            n = p.u8()
            args = [p.operand()[1] for _ in range(n)]
            assert p.u8() == 0x40
            return '%s(%s)' % (name, ','.join(args)), 0, False
        return name, 3, False

    if op == 0x95:                                        # PAYLOAD[n]
        assert p.u8() == 0x01 and p.u8() == 0x00 and p.u8() == 0x02
        return 'PAYLOAD[%d]' % p.u16(), 0, False

    if op in VAR_NAME:                                    # <var> = <expr>
        lhs = p.operand(op)[1]
        assert p.u8() == 0x64
        return '%s=%s' % (lhs, rhs_expr(p)), (3 if op == 0x04 else 0), False

    raise ValueError('opcode %02X: %s' % (op, body.hex(' ')))

def decode_record(body):
    t, extra, motion = decode_body(body)
    indent = '' if motion and body[0] == 0xFE else '  '
    return indent + t + ' ' * extra

def decode_mn(raw, start=MN_START, end=MN_END):
    out = []
    for n, (off, body, pad) in enumerate(split_records(raw, start, end), 1):
        out.append('%4d:%s ;' % (n, decode_record(body)))
    return out

if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else 'PG21.tp.raw0'
    raw = open(path, 'rb').read()
    a = int(sys.argv[2], 0) if len(sys.argv) > 3 else MN_START
    b = int(sys.argv[3], 0) if len(sys.argv) > 3 else MN_END
    sys.stdout.write('\r\n'.join(decode_mn(raw, a, b)) + '\r\n')
