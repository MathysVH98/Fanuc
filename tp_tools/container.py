"""Shared toolkit: FANUC .TP LZSS container + record splitter."""
import struct

N=4096; F=18; THRESHOLD=2

# The ring buffer is prefilled with 0x00. Okumura's original lzss.c uses 0x20
# (space); FANUC deviated. Verified against PG21.LS line 549 `GO[10]=0`, whose
# value operand decodes as 0x00 under this fill and as 0x20 (=32) under a space
# fill. 361 of the 9409 payload bytes differ between the two.
RING_FILL_BYTE = b"\x00"

def decompress(data):
    assert data[:2]==b'\xfe\xef', 'bad magic'
    ver = struct.unpack('>H', data[2:4])[0]
    size = struct.unpack('>I', data[4:8])[0]
    win = bytearray(RING_FILL_BYTE * N); r = N - F
    out = bytearray(); i = 8; L=len(data)
    while i < L and len(out) < size:
        flags = data[i]; i+=1
        for b in range(8):
            if i>=L or len(out)>=size: break
            if (flags>>b)&1:
                c=data[i]; i+=1
                out.append(c); win[r]=c; r=(r+1)%N
            else:
                if i+1>=L: break
                b1,b2=data[i],data[i+1]; i+=2
                off = b1 | ((b2 & 0xF0)<<4)
                ln  = (b2 & 0x0F) + THRESHOLD + 1
                for k in range(ln):
                    c=win[(off+k)%N]
                    out.append(c); win[r]=c; r=(r+1)%N
    assert len(out)==size, (len(out), size)
    return bytes(out), ver

def compress(raw, ver=1):
    """Compress to a .TP. Delegates to the canonical Okumura port, which
    reproduces FANUC's own output byte for byte on the reference program."""
    from . import lzss_encode
    return lzss_encode.compress(raw, ver)


def split_records(raw, start, end):
    """Yield (offset, opcode, payload_bytes, tail2) ; record total = len+2."""
    p=start
    recs=[]
    while p < end:
        ln = raw[p]
        if ln == 0: break
        total = ln+2
        rec = raw[p:p+total]
        op = rec[1] if ln>=2 else None
        recs.append((p, ln, op, rec[2:ln] if ln>2 else b'', rec[ln:ln+2]))
        p += total
    return recs
