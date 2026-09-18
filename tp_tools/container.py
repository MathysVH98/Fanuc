"""Shared toolkit: FANUC .TP LZSS container + record splitter."""
import struct

N=4096; F=18; THRESHOLD=2

def decompress(data):
    assert data[:2]==b'\xfe\xef', 'bad magic'
    ver = struct.unpack('>H', data[2:4])[0]
    size = struct.unpack('>I', data[4:8])[0]
    win = bytearray(b' '*N); r = N-F
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
    """Greedy-longest-match LZSS producing the same stream shape."""
    win = bytearray(b' '*N); r = N-F
    out = bytearray(); i=0; L=len(raw)
    flagbuf=bytearray(); flags=0; nbits=0; chunk=bytearray()
    def flush():
        nonlocal flags,nbits,chunk
        if nbits:
            out.append(flags); out.extend(chunk)
        flags=0; nbits=0; chunk=bytearray()
    while i < L:
        best_len=0; best_off=0
        maxlen=min(F, L-i)
        if maxlen >= THRESHOLD+1:
            # search ring buffer for longest match
            for off in range(N):
                ln=0
                while ln<maxlen and win[(off+ln)%N]==raw[i+ln]:
                    ln+=1
                if ln>best_len:
                    best_len=ln; best_off=off
                    if ln==maxlen: break
        if best_len > THRESHOLD:
            chunk.append(best_off & 0xFF)
            chunk.append(((best_off>>4)&0xF0) | (best_len-THRESHOLD-1))
            for k in range(best_len):
                win[r]=raw[i+k]; r=(r+1)%N
            i+=best_len
        else:
            flags |= (1<<nbits)
            chunk.append(raw[i]); win[r]=raw[i]; r=(r+1)%N; i+=1
        nbits+=1
        if nbits==8: flush()
    flush()
    return b'\xfe\xef'+struct.pack('>H',ver)+struct.pack('>I',len(raw))+bytes(out)

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
