"""FANUC .TP LZSS compressor.

A faithful Python port of Haruhiko Okumura's public-domain `lzss.c` (1989) Encode(),
parameterised for the FANUC .TP container:

    N = 4096            ring buffer size
    F = 18              upper limit for match_length
    THRESHOLD = 2       encode as a pair only when match_length > THRESHOLD
    FILL = 0x00         ring prefill byte (FANUC deviates from Okumura's ' ')

The match finder is Okumura's binary search tree (lson/rson/dad + InsertNode /
DeleteNode).  Its tie-breaking is an emergent property of the BST, not "most
recent" / "lowest offset", which is why a naive greedy-longest-match encoder
does NOT reproduce the original byte stream.

VERIFIED: compress(PG21.tp.raw0) == PG21.TP, byte for byte (4233/4233 bytes,
0 differing bytes).  See LZSS_NOTES.md.

Public API
----------
    compress_stream(raw)        -> bytes   LZSS stream only
    compress(raw, version=1)    -> bytes   8-byte container header + stream
    decompress(data)            -> (bytes, version)   inverse, for self-checks
"""

import struct

N = 4096            # size of ring buffer
F = 18              # upper limit for match_length
THRESHOLD = 2
NIL = N             # index for root of binary search trees
FILL = 0x00         # ring prefill byte used by FANUC

MAGIC = b'\xfe\xef'


class _Encoder:
    """One-shot encoder.  Mirrors the C source line for line."""

    __slots__ = ('raw', 'pos', 'text_buf', 'lson', 'rson', 'dad',
                 'match_position', 'match_length', 'out')

    def __init__(self, raw):
        self.raw = raw
        self.pos = 0
        # C: unsigned char text_buf[N + F - 1];      (static -> zero filled)
        self.text_buf = bytearray(N + F - 1)
        # C: int lson[N + 1], rson[N + 257], dad[N + 1];
        self.lson = [0] * (N + 1)
        self.rson = [0] * (N + 257)
        self.dad = [0] * (N + 1)
        self.match_position = 0
        self.match_length = 0
        self.out = bytearray()

    def _getc(self):
        if self.pos >= len(self.raw):
            return -1
        c = self.raw[self.pos]
        self.pos += 1
        return c

    # ---- binary search tree -------------------------------------------
    def InitTree(self):
        for i in range(N + 1, N + 257):
            self.rson[i] = NIL
        for i in range(N):
            self.dad[i] = NIL

    def InsertNode(self, r):
        """Insert string text_buf[r..r+F-1] and set match_position/match_length
        to the longest match found on the way down."""
        text_buf = self.text_buf
        lson, rson, dad = self.lson, self.rson, self.dad
        cmp = 1
        p = N + 1 + text_buf[r]
        rson[r] = lson[r] = NIL
        self.match_length = 0
        while True:
            if cmp >= 0:
                if rson[p] != NIL:
                    p = rson[p]
                else:
                    rson[p] = r
                    dad[r] = p
                    return
            else:
                if lson[p] != NIL:
                    p = lson[p]
                else:
                    lson[p] = r
                    dad[r] = p
                    return
            i = 1
            while i < F:
                cmp = text_buf[r + i] - text_buf[p + i]
                if cmp != 0:
                    break
                i += 1
            if i > self.match_length:
                self.match_position = p
                self.match_length = i
                if i >= F:
                    break
        # identical for F bytes: replace node p with node r
        dad[r] = dad[p]
        lson[r] = lson[p]
        rson[r] = rson[p]
        dad[lson[p]] = r
        dad[rson[p]] = r
        if rson[dad[p]] == p:
            rson[dad[p]] = r
        else:
            lson[dad[p]] = r
        dad[p] = NIL

    def DeleteNode(self, p):
        lson, rson, dad = self.lson, self.rson, self.dad
        if dad[p] == NIL:
            return                      # not in tree
        if rson[p] == NIL:
            q = lson[p]
        elif lson[p] == NIL:
            q = rson[p]
        else:
            q = lson[p]
            if rson[q] != NIL:
                while True:
                    q = rson[q]
                    if rson[q] == NIL:
                        break
                rson[dad[q]] = lson[q]
                dad[lson[q]] = dad[q]
                lson[q] = lson[p]
                dad[lson[p]] = q
            rson[q] = rson[p]
            dad[rson[p]] = q
        dad[q] = dad[p]
        if rson[dad[p]] == p:
            rson[dad[p]] = q
        else:
            lson[dad[p]] = q
        dad[p] = NIL

    # ---- Encode() -----------------------------------------------------
    def Encode(self):
        text_buf = self.text_buf
        out = self.out
        self.InitTree()
        code_buf = bytearray(17)
        code_buf[0] = 0
        code_buf_ptr = 1
        mask = 1
        s = 0
        r = N - F
        for i in range(s, r):
            text_buf[i] = FILL
        length = 0
        while length < F:
            c = self._getc()
            if c < 0:
                break
            text_buf[r + length] = c
            length += 1
        if length == 0:
            return b''                  # text of size zero
        for i in range(1, F + 1):
            self.InsertNode(r - i)
        self.InsertNode(r)
        while True:
            if self.match_length > length:
                self.match_length = length
            if self.match_length <= THRESHOLD:
                self.match_length = 1
                code_buf[0] |= mask
                code_buf[code_buf_ptr] = text_buf[r]
                code_buf_ptr += 1
            else:
                code_buf[code_buf_ptr] = self.match_position & 0xFF
                code_buf_ptr += 1
                code_buf[code_buf_ptr] = (((self.match_position >> 4) & 0xF0)
                                          | (self.match_length - (THRESHOLD + 1))) & 0xFF
                code_buf_ptr += 1
            mask = (mask << 1) & 0xFF
            if mask == 0:
                out.extend(code_buf[:code_buf_ptr])
                code_buf[0] = 0
                code_buf_ptr = 1
                mask = 1
            last_match_length = self.match_length
            i = 0
            while i < last_match_length:
                c = self._getc()
                if c < 0:
                    break
                self.DeleteNode(s)
                text_buf[s] = c
                if s < F - 1:
                    text_buf[s + N] = c
                s = (s + 1) & (N - 1)
                r = (r + 1) & (N - 1)
                self.InsertNode(r)
                i += 1
            while i < last_match_length:        # C: while (i++ < last_match_length)
                i += 1
                self.DeleteNode(s)
                s = (s + 1) & (N - 1)
                r = (r + 1) & (N - 1)
                length -= 1
                if length:
                    self.InsertNode(r)
            if length <= 0:
                break
        if code_buf_ptr > 1:
            out.extend(code_buf[:code_buf_ptr])
        return bytes(out)


def compress_stream(raw):
    """Compress `raw` to a bare LZSS stream (no container header)."""
    return _Encoder(bytes(raw)).Encode()


def compress(raw, version=1):
    """Compress `raw` into a full FANUC .TP container:
    magic FE EF | u16BE version | u32BE uncompressed size | LZSS stream."""
    raw = bytes(raw)
    return (MAGIC + struct.pack('>H', version) + struct.pack('>I', len(raw))
            + compress_stream(raw))


def decompress(data):
    """Inverse of compress(); returns (payload, version).  Uses FILL=0x00."""
    if data[:2] != MAGIC:
        raise ValueError('bad magic %r' % (data[:2],))
    version = struct.unpack('>H', data[2:4])[0]
    size = struct.unpack('>I', data[4:8])[0]
    win = bytearray([FILL]) * N
    r = N - F
    out = bytearray()
    i = 8
    L = len(data)
    while i < L and len(out) < size:
        flags = data[i]
        i += 1
        for b in range(8):
            if i >= L or len(out) >= size:
                break
            if (flags >> b) & 1:
                c = data[i]
                i += 1
                out.append(c)
                win[r] = c
                r = (r + 1) % N
            else:
                if i + 1 >= L:
                    break
                b1, b2 = data[i], data[i + 1]
                i += 2
                off = b1 | ((b2 & 0xF0) << 4)
                ln = (b2 & 0x0F) + THRESHOLD + 1
                for k in range(ln):
                    c = win[(off + k) % N]
                    out.append(c)
                    win[r] = c
                    r = (r + 1) % N
    if len(out) != size:
        raise ValueError('short stream: %d != %d' % (len(out), size))
    return bytes(out), version


if __name__ == '__main__':
    import os, sys, random
    d = os.path.dirname(os.path.abspath(__file__))
    raw = open(os.path.join(d, 'PG21.tp.raw0'), 'rb').read()
    ref = open(os.path.join(d, 'PG21.TP'), 'rb').read()
    mine = compress(raw)
    nd = sum(1 for a, b in zip(mine, ref) if a != b) + abs(len(mine) - len(ref))
    print('PG21: mine=%d ref=%d differing_bytes=%d IDENTICAL=%s'
          % (len(mine), len(ref), nd, mine == ref))
    random.seed(1234)
    bad = 0
    cases = [raw[:n] for n in (0, 1, 2, 17, 18, 19, 100, 4095, 4096, 4097, 5000, 9408, 9409)]
    cases += [b'', b'\x00' * 70000, bytes(random.randrange(256) for _ in range(5000))]
    for n in (3, 300, 3000):
        m = bytearray(raw)
        for _ in range(n):
            m[random.randrange(len(m))] = random.randrange(256)
        cases.append(bytes(m))
    for c in cases:
        blob = compress(c)
        try:
            back, ver = decompress(blob)
        except Exception as e:
            print('FAIL len=%d: %s' % (len(c), e)); bad += 1; continue
        if back != c:
            print('FAIL round-trip len=%d' % len(c)); bad += 1
    print('round-trip cases: %d, failures: %d' % (len(cases), bad))
    sys.exit(1 if bad else 0)
