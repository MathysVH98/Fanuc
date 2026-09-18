"""Gates for the /MN instruction codec, measured against the reference pair."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from tp_tools import container, mn_decode, mn_encode

HERE = os.path.dirname(__file__)
FIX = os.path.join(HERE, '..', 'fixtures')

# /MN body of PG21.LS: the 550 numbered lines between /MN and /POS.
MN_FIRST_LINE, MN_LAST_LINE = 34, 583


def _ref_raw():
    return container.decompress(open(os.path.join(FIX, 'PG21.TP'), 'rb').read())[0]


def _ref_mn_text():
    text = open(os.path.join(FIX, 'PG21.LS'), encoding='latin-1').read()
    lines = [l.rstrip('\r') for l in text.split('\n')[MN_FIRST_LINE - 1:MN_LAST_LINE]]
    return ('\r\n'.join(lines) + '\r\n').encode('latin-1')


def test_decode_reproduces_reference_ls_exactly():
    """Decoding the reference .TP must reproduce its .LS /MN text byte for byte."""
    got = '\r\n'.join(mn_decode.decode_mn(_ref_raw())).encode('latin-1') + b'\r\n'
    want = _ref_mn_text()
    assert got == want, f'{len(got)} bytes decoded vs {len(want)} expected'


def test_encode_roundtrips_all_but_the_lossy_record():
    """Re-encoding the reference .LS must reproduce the reference bytes.

    Exactly one record cannot round-trip, and it is a limitation of the .LS
    format rather than of this codec: PG21.LS line 207 stores float32(179.9)
    = 0x4333E666, but FANUC truncates reals to 3 decimals when printing, so it
    displays as "179.899" -- identical to how float32(179.899) = 0x4333E625
    displays. The text cannot distinguish the two. That line appears only in
    the reference, never in a program we convert.
    """
    raw = _ref_raw()
    ref = raw[0x7F:0x1E97]
    lines = mn_decode.decode_mn(raw)
    got = mn_encode.enc_mn(lines)
    assert len(got) == len(ref)

    bad = []
    p = 0
    for i in range(550):
        n = ref[p] + 2
        if ref[p:p + n] != got[p:p + n]:
            bad.append(i + 1)
        p += n
    assert bad == [207], f'expected only line 207 to differ, got {bad}'


def test_target_program_encodes_without_error():
    """Every line of the program we are converting must encode."""
    text = open(os.path.join(FIX, 'PG21T5FX.LS'), encoding='latin-1').read()
    lines = [l.rstrip('\r') for l in text.split('\n')]
    start = lines.index('/MN') + 1
    end = next(i for i, l in enumerate(lines) if l.startswith('/POS'))
    body = lines[start:end]
    assert len(body) == 599, len(body)
    blob = mn_encode.enc_mn(body)
    assert len(blob) > 0


if __name__ == '__main__':
    fails = 0
    for fn in sorted(k for k in dir() if k.startswith('test_')):
        try:
            globals()[fn]()
            print('PASS', fn)
        except Exception as e:
            fails += 1
            print('FAIL', fn, type(e).__name__, e)
    raise SystemExit(1 if fails else 0)
