"""Plain-assert tests for the pure night-reskin transform (M0 Task 1).
Run: python3 test_reskin.py  (no pytest / no new deps)."""
from reskin import reskin_pixel, saturation


def test_transparent_pixel_stays_transparent():
    assert reskin_pixel(216, 216, 192, 0, style='c') == (0, 0, 0, 0)


def test_cream_ground_becomes_dark_slate_c():
    # the dominant cream ground -> near the slate floor, NOT bright
    r, g, b, a = reskin_pixel(216, 216, 192, 255, style='c')
    assert a == 255
    assert r < 70 and g < 80 and b < 100, (r, g, b)   # dark
    assert b >= r                                       # slate is blue-ish


def test_saturated_ink_is_preserved_c():
    # a saturated blue parking mark keeps its hue (dimmed), not slate-flattened
    r, g, b, a = reskin_pixel(59, 130, 246, 255, style='c')  # #3B82F6
    assert b > r and b > g, (r, g, b)                   # still clearly blue
    assert saturation(r, g, b) > 0.25                   # ink not desaturated to slate


def test_deterministic():
    assert reskin_pixel(200, 100, 50, 255, style='c') == \
        reskin_pixel(200, 100, 50, 255, style='c')


def test_style_b_inverts_luminance():
    dark_ground = reskin_pixel(216, 216, 192, 255, style='b')  # bright cream -> dark
    assert sum(dark_ground[:3]) < 240, dark_ground


if __name__ == '__main__':
    fns = [v for k, v in sorted(globals().items())
           if k.startswith('test_') and callable(v)]
    for fn in fns:
        fn()
        print('ok', fn.__name__)
    print(f'{len(fns)} passed')
