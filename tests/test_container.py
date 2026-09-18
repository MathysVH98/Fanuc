"""Gates for the .TP LZSS container."""
import os, random, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from tp_tools import container

FIXTURES = os.path.join(os.path.dirname(__file__), '..', 'fixtures')
REF_TP = os.path.join(FIXTURES, 'PG21.TP')


def test_reference_decompresses_to_declared_size():
    """The header's size field must match what the stream actually yields."""
    data = open(REF_TP, 'rb').read()
    raw, ver = container.decompress(data)
    assert ver == 1
    assert len(raw) == int.from_bytes(data[4:8], 'big') == 9409


def test_reference_record_framing():
    """/MN must parse as exactly LINE_COUNT records, ending on the /POS boundary."""
    raw, _ = container.decompress(open(REF_TP, 'rb').read())
    recs = container.split_records(raw, 0x7F, 0x1E97)
    assert len(recs) == 550, len(recs)
    last_off, last_len = recs[-1][0], recs[-1][1]
    assert last_off + last_len + 2 == 0x1E97


def test_byte_identical_recompression():
    """The strongest gate: re-compressing the reference payload must reproduce
    FANUC's own bytes exactly, not merely something that decompresses correctly."""
    ref = open(REF_TP, 'rb').read()
    raw, ver = container.decompress(ref)
    assert container.compress(raw, ver) == ref


def _roundtrip_cases():
    raw, _ = container.decompress(open(REF_TP, 'rb').read())
    random.seed(7)
    cases = [('reference', raw), ('empty', b''), ('doubled', raw + raw),
             ('incompressible', bytes(random.randrange(256) for _ in range(5000))),
             ('all-spaces', b' ' * 3000)]
    # sizes around the ring-buffer and max-match boundaries
    for n in (1, 2, 3, 17, 18, 19, 255, 4095, 4096, 4097, len(raw) - 1):
        cases.append((f'truncated-{n}', raw[:n]))
    return cases


def test_compress_roundtrip():
    from tp_tools import lzss_encode
    for name, payload in _roundtrip_cases():
        out = lzss_encode.compress(payload)
        back, _ = container.decompress(out)
        assert back == payload, name


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
