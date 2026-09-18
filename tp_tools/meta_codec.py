"""
meta_codec.py -- decoder/encoder for the NON-/MN parts of a FANUC .TP binary
(operating on the LZSS-decompressed image, e.g. PG21.tp.raw).

Covers three sections (offsets for PG21.tp.raw, 9409 bytes):

  A  0x0000 .. 0x007D   file preamble + program name + `FF FF 01` + /ATTR record
                        + `FF FF 02`   (the /MN section body starts at 0x007E)
  B  0x1E96 .. 0x246C   `FF FF 03` + 40 /POS records
  C  0x246D .. 0x24C0   `FF FF 04` + 7 /APPL records + `FF FF` EOF marker

The /MN body (0x007E..0x1E95) is NOT handled here.

Generic container grammar discovered (see META_SPEC.md):
  section marker : FF FF <u8 section_id>
  /ATTR,/MN,/POS record : <u16BE len> <len bytes>
  /APPL record          : <u16BE block_idx> <u16BE sub_idx> <u8 len> <len bytes>
  end of file           : FF FF

All multi-byte integers are BIG ENDIAN. All floats are IEEE-754 binary32 BIG ENDIAN.
0x00 is used as "unset / filler" padding throughout (fixed-width strings are NUL-padded).
"""

import struct
import math

# ---------------------------------------------------------------- boundaries
A_START, A_END = 0x0000, 0x007E      # [start, end)
MN_START, MN_END = 0x007E, 0x1E96
B_START, B_END = 0x1E96, 0x246D
C_START, C_END = 0x246D, 0x24C1

u16 = lambda b, o: struct.unpack_from('>H', b, o)[0]
u32 = lambda b, o: struct.unpack_from('>I', b, o)[0]
p16 = lambda v: struct.pack('>H', v)
p32 = lambda v: struct.pack('>I', v)


# ============================================================ FANUC date/time
# A timestamp is a 32-bit big-endian word: (dos_date << 16) | dos_time
#   dos_date : bits 15..9 year-1980, bits 8..5 month(1-12), bits 4..0 day(1-31)
#   dos_time : bits 15..11 hour,     bits 10..5 minute,     bits 4..0 second/2
# The .LS prints the year modulo 100.
def decode_dt(word):
    d, t = word >> 16, word & 0xFFFF
    year = 1980 + (d >> 9)
    return dict(year=year, month=(d >> 5) & 0x0F, day=d & 0x1F,
                hour=t >> 11, minute=(t >> 5) & 0x3F, second=(t & 0x1F) * 2)


def encode_dt(dt):
    d = ((dt['year'] - 1980) << 9) | (dt['month'] << 5) | dt['day']
    t = (dt['hour'] << 11) | (dt['minute'] << 5) | (dt['second'] // 2)
    return (d << 16) | t


def dt_str(dt):
    return "DATE %02d-%02d-%02d  TIME %02d:%02d:%02d" % (
        dt['year'] % 100, dt['month'], dt['day'],
        dt['hour'], dt['minute'], dt['second'])


# =========================================================== SECTION A header
def decode_header(buf):
    """buf = raw[0x0000:0x007E].  Returns a dict."""
    assert len(buf) == 0x7E, len(buf)
    h = {}
    h['pre'] = buf[0x00:0x04]                       # 00 00 03 00  (unexplained)
    h['name'] = buf[0x04:0x28].decode('ascii').rstrip('\x00')   # 36 bytes, NUL padded
    h['name_term'] = buf[0x28:0x2A]                 # 00 00
    assert buf[0x2A:0x2D] == b'\xff\xff\x01'
    h['attr_len'] = u16(buf, 0x2D)                  # 0x004C = 76
    assert 0x2F + h['attr_len'] == 0x7B

    h['owner'] = buf[0x2F:0x37].decode('ascii').rstrip('\x00')  # "MNEDITOR"
    h['owner_term'] = buf[0x37:0x39]                # 00 00
    h['comment'] = buf[0x39:0x4B].decode('ascii').rstrip('\x00')  # 18 bytes, NUL padded
    h['prog_size'] = u32(buf, 0x4B)                 # 12956
    h['create'] = decode_dt(u32(buf, 0x4F))
    h['modified'] = decode_dt(u32(buf, 0x53))
    h['unk_57'] = buf[0x57:0x5B]                    # 20 20 20 20  (unexplained)
    h['line_count'] = u32(buf, 0x5B)                # 550
    h['memory_size'] = u32(buf, 0x5F)               # 13648
    h['unk_63'] = buf[0x63:0x7B]                    # 24 bytes (see META_SPEC)
    assert buf[0x7B:0x7E] == b'\xff\xff\x02'
    return h


def encode_header(h):
    name = h['name'].encode('ascii').ljust(36, b'\x00')[:36]
    comment = h['comment'].encode('ascii').ljust(18, b'\x00')[:18]
    owner = h['owner'].encode('ascii').ljust(8, b'\x00')[:8]
    attr = (owner + h['owner_term'] + comment
            + p32(h['prog_size'])
            + p32(encode_dt(h['create']))
            + p32(encode_dt(h['modified']))
            + h['unk_57']
            + p32(h['line_count'])
            + p32(h['memory_size'])
            + h['unk_63'])
    return (h['pre'] + name + h['name_term']
            + b'\xff\xff\x01' + p16(len(attr)) + attr
            + b'\xff\xff\x02')


# ============================================================= SECTION B /POS
# record bytes +3..+6 ('sig'), constant per kind in PG21
JOINT_SIG = bytes.fromhex('001c1930')
CART_SIG = bytes.fromhex('00201200')


def decode_pos(buf):
    """buf = raw[0x1E96:0x246D].  Returns list of position dicts."""
    assert buf[0:3] == b'\xff\xff\x03'
    out = []
    p = 3
    while p < len(buf):
        ln = u16(buf, p)
        d = buf[p + 2:p + 2 + ln]
        p += 2 + ln
        rec = {}
        rec['posno'] = u16(d, 0)
        rec['group'] = d[2]                 # 0x01 = GP1
        rec['sig'] = d[3:7]                 # 4-byte kind signature
        rec['uf'] = d[7] >> 4               # UF nibble
        rec['ut'] = d[7] & 0x0F             # UT nibble
        rec['vals'] = list(struct.unpack('>6f', d[8:32]))
        if ln == 36:
            rec['kind'] = 'CART'            # vals = X,Y,Z (mm), W,P,R (deg)
            rec['cfg'] = d[32:36]           # 4 cfg bytes; cfg[2] = J6 turn (s8)
        elif ln == 32:
            rec['kind'] = 'JOINT'           # vals = J1..J6 in RADIANS
            rec['cfg'] = None
        else:
            raise ValueError('unknown /POS record length %d at %04X' % (ln, p))
        out.append(rec)
    return out


def encode_pos(recs):
    out = bytearray(b'\xff\xff\x03')
    for r in recs:
        d = (p16(r['posno']) + bytes([r['group']]) + r['sig']
             + bytes([(r['uf'] << 4) | r['ut']])
             + struct.pack('>6f', *r['vals']))
        if r['kind'] == 'CART':
            d += r['cfg']
        out += p16(len(d)) + d
    return bytes(out)


# -- convenience: engineering units -----------------------------------------
def pos_engineering(rec):
    """Return the 6 values as the .LS prints them (deg / mm)."""
    if rec['kind'] == 'JOINT':
        return [math.degrees(v) for v in rec['vals']]
    return list(rec['vals'])


def turns(rec):
    """The three CONFIG turn numbers (signed int8) of a cartesian record.

    Verified equal to the 'N U T, t1, t2, t3' triple printed by PG21.LS for all
    33 cartesian records.  Joint records have no CONFIG and return None.
    """
    if rec['kind'] != 'CART':
        return None
    return tuple(struct.unpack('>3b', rec['cfg'][0:3]))


def turn_j6(rec):
    """Third CONFIG turn number (the one that is 0 or -1 in PG21)."""
    t = turns(rec)
    return None if t is None else t[2]


def make_cart_cfg(t1=0, t2=0, t3=0, flags=0x31):
    """Build the 4 CONFIG bytes for a NEW cartesian point.

    flags=0x31 is what 32 of PG21's 33 cartesian records carry (P[25] has 0x30;
    the difference is unexplained -- see META_SPEC.md 2.3).
    """
    return struct.pack('>3bB', t1, t2, t3, flags)


# ============================================================ SECTION C /APPL
def decode_appl(buf):
    """buf = raw[0x246D:0x24C1].  Returns list of records + eof marker."""
    assert buf[0:3] == b'\xff\xff\x04'
    out = []
    p = 3
    while p < len(buf) - 2:
        # <u16BE idx> <u16BE sub> <u8 len> <body>
        idx, sub, ln = u16(buf, p), u16(buf, p + 2), buf[p + 4]
        body = buf[p + 5:p + 5 + ln]
        p += 5 + ln
        out.append(dict(idx=idx, sub=sub, body=body))
    assert buf[p:] == b'\xff\xff', buf[p:].hex()
    return out


def encode_appl(recs):
    out = bytearray(b'\xff\xff\x04')
    for r in recs:
        out += p16(r['idx']) + p16(r['sub']) + bytes([len(r['body'])]) + r['body']
    out += b'\xff\xff'
    return bytes(out)


# ================================================================ self-test
def _report(name, orig, again):
    if orig == again:
        print("  %-8s OK  %d bytes round-tripped byte-for-byte" % (name, len(orig)))
        return True
    print("  %-8s FAIL len %d -> %d" % (name, len(orig), len(again)))
    n = 0
    for i in range(min(len(orig), len(again))):
        if orig[i] != again[i]:
            print("     mismatch at section offset 0x%04X: %02X != %02X"
                  % (i, orig[i], again[i]))
            n += 1
            if n > 20:
                print("     ...")
                break
    return False


def selftest(path='PG21.tp.raw0'):
    raw = open(path, 'rb').read()
    ok = True
    A = raw[A_START:A_END]
    ok &= _report('HEADER', A, encode_header(decode_header(A)))
    B = raw[B_START:B_END]
    ok &= _report('/POS', B, encode_pos(decode_pos(B)))
    C = raw[C_START:C_END]
    ok &= _report('/APPL', C, encode_appl(decode_appl(C)))
    # whole-file reassembly (MN passed through untouched)
    rebuilt = (encode_header(decode_header(A)) + raw[MN_START:MN_END]
               + encode_pos(decode_pos(B)) + encode_appl(decode_appl(C)))
    ok &= _report('WHOLE', raw, rebuilt)
    return ok


if __name__ == '__main__':
    import sys
    sys.exit(0 if selftest() else 1)


# ============================================================ target helpers
def build_target_sections(raw, name='PG21T5FX', comment='PG21T 5 BAY CMT',
                          file_name='PG21T5FX', line_count=599,
                          modified=None, prog_size=None, memory_size=None):
    """Produce the A / B / C byte blocks for the PG21T5FX variant.

    Everything not named here is copied verbatim from `raw` (PG21.tp.raw).
    P[57] is created by cloning P[56]'s record and changing only the number,
    which is exact for PG21T5FX.LS because its P[57] has identical values.
    """
    h = decode_header(raw[A_START:A_END])
    h['name'] = name
    h['comment'] = comment
    h['line_count'] = line_count
    if prog_size is not None:
        h['prog_size'] = prog_size
    if memory_size is not None:
        h['memory_size'] = memory_size
    if modified is not None:
        h['modified'] = modified          # dict(year,month,day,hour,minute,second)

    pos = decode_pos(raw[B_START:B_END])
    p56 = [r for r in pos if r['posno'] == 56][0]
    p57 = dict(p56)
    p57['posno'] = 57
    pos.append(p57)

    appl = decode_appl(raw[C_START:C_END])
    for r in appl:
        if r['body'][:4] == b'LANG':
            r['body'] = b'LANG' + file_name.encode('ascii') + b'\x00\x00'
    return encode_header(h), encode_pos(pos), encode_appl(appl)


def demo_target(path='PG21.tp.raw0'):
    raw = open(path, 'rb').read()
    A, B, C = build_target_sections(
        raw, modified=dict(year=2026, month=9, day=18,
                           hour=0, minute=48, second=0))
    print("target A: %d bytes (was %d)" % (len(A), A_END - A_START))
    print("target B: %d bytes (was %d)" % (len(B), B_END - B_START))
    print("target C: %d bytes (was %d)" % (len(C), C_END - C_START))
    print("A hex:", A.hex(' '))
    print("C hex:", C.hex(' '))
    print("new P57 record:", B[-38:].hex(' '))
