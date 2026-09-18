"""End-to-end gates: .LS -> .TP -> .LS."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from tp_tools import build, container, mn_decode, ls_parse

FIX = os.path.join(os.path.dirname(__file__), '..', 'fixtures')
REF_TP = os.path.join(FIX, 'PG21.TP')
TGT_LS = os.path.join(FIX, 'PG21T5FX.LS')

# The 8 lines of PG21T5FX.LS whose motion records were un-commented by hand and
# kept the two-space indent FANUC uses only for non-motion lines. The encoder
# accepts both spellings and emits identical bytes; the decoder always writes
# the canonical form, so these differ in text only.
HAND_INDENTED = {81, 105, 198, 205, 217, 224, 242, 449}


def _ref_payload():
    return container.decompress(open(REF_TP, 'rb').read())[0]


def _target_payload():
    prog = ls_parse.parse(TGT_LS)
    return build.build(_ref_payload(), TGT_LS,
                       name='PG21T5FX', comment='PG21T 5 BAY CMT',
                       file_name='PG21T5FX',
                       modified=dict(year=2026, month=9, day=18,
                                     hour=0, minute=48, second=0))


def test_reference_rebuilds_from_its_own_ls():
    """Rebuilding the reference program from its own .LS must reproduce it,
    apart from the single record the .LS cannot represent."""
    ref = _ref_payload()
    _, mn, _, _ = build.split_sections(ref)
    got = build.mn_section(build.ls_mn_lines(os.path.join(FIX, 'PG21.LS')))
    assert len(got) == len(mn)
    diff = [i for i in range(len(mn)) if mn[i] != got[i]]
    assert len(diff) == 1, diff          # float32(179.9) vs float32(179.899)


def test_target_mn_roundtrips():
    """Decoding the .TP we emit must reproduce the source /MN text."""
    payload = _target_payload()
    _, pos_mark, _ = build.find_sections(payload)
    got = mn_decode.decode_mn(payload, 0x7F, pos_mark + 1)
    want = build.ls_mn_lines(TGT_LS)
    assert len(got) == len(want) == 599
    bad = {i + 1 for i, (w, g) in enumerate(zip(want, got)) if w.rstrip() != g.rstrip()}
    assert bad <= HAND_INDENTED, sorted(bad - HAND_INDENTED)


def test_shared_positions_are_bit_identical():
    """Taught positions must survive as the exact bytes the controller wrote."""
    ref, out = _ref_payload(), _target_payload()
    a, b = build.pos_records(ref), build.pos_records(out)
    shared = sorted(set(a) & set(b))
    assert len(shared) == 40
    assert all(a[n] == b[n] for n in shared)


def test_new_position_is_an_exact_copy_of_its_twin():
    """P[57] is declared identical to P[56], so it must be a byte-copy."""
    out = _target_payload()
    recs = build.pos_records(out)
    assert set(recs) == set(build.pos_records(_ref_payload())) | {57}
    p56, p57 = recs[56], recs[57]
    assert p57[2:4] == (57).to_bytes(2, 'big')
    assert p57[:2] == p56[:2] and p57[4:] == p56[4:]


def test_container_declares_the_right_size():
    tp = container.compress(_target_payload())
    back, ver = container.decompress(tp)
    assert ver == 1
    assert back == _target_payload()
    assert int.from_bytes(tp[4:8], 'big') == len(back)


def test_refuses_to_invent_a_position():
    """A position with no bit-exact twin must raise rather than silently
    encode a shifted value from the .LS text."""
    import copy
    prog = ls_parse.parse(TGT_LS)
    victim = next(p for p in prog.positions if p.num == 57)
    victim.vals = [v + 1.0 for v in victim.vals]
    try:
        build.build_pos(_ref_payload(), prog)
    except ValueError as e:
        assert 'P[57]' in str(e)
    else:
        raise AssertionError('expected a refusal for an untwinned position')


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
