import numpy as np
import pytest

from xhisper_streamd import RingBuffer


def test_appends_and_normalizes_int16_to_float32():
    rb = RingBuffer(max_samples=10)
    rb.append(np.array([0, 16384, -16384, 32767, -32768], dtype=np.int16).tobytes())
    audio = rb.audio()
    assert audio.dtype == np.float32
    assert audio.shape == (5,)
    assert audio[0] == pytest.approx(0.0)
    assert audio[1] == pytest.approx(0.5, abs=1e-3)
    assert audio[2] == pytest.approx(-0.5, abs=1e-3)
    assert audio[3] == pytest.approx(1.0, abs=1e-3)
    assert audio[4] == pytest.approx(-1.0, abs=1e-3)


def test_trims_to_max_samples_keeping_tail():
    rb = RingBuffer(max_samples=4)
    rb.append(np.array([1, 2, 3, 4, 5, 6], dtype=np.int16).tobytes())
    audio = rb.audio()
    assert audio.shape == (4,)
    # last four input samples scaled to float32 (3..6)
    expected = np.array([3, 4, 5, 6], dtype=np.float32) / 32768.0
    np.testing.assert_allclose(audio, expected, atol=1e-6)


def test_drop_front_removes_consumed_samples():
    rb = RingBuffer(max_samples=10)
    rb.append(np.array([1, 2, 3, 4, 5], dtype=np.int16).tobytes())
    rb.drop_front(2)
    audio = rb.audio()
    assert audio.shape == (3,)
    expected = np.array([3, 4, 5], dtype=np.float32) / 32768.0
    np.testing.assert_allclose(audio, expected, atol=1e-6)
