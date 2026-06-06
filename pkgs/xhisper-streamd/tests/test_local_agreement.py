from xhisper_streamd import longest_agreed_prefix


def test_returns_empty_when_history_shorter_than_n():
    assert longest_agreed_prefix([["hello", "world"]], n=2) == []


def test_returns_full_prefix_when_all_agree():
    history = [
        ["hello", "world", "how"],
        ["hello", "world", "how", "are"],
    ]
    assert longest_agreed_prefix(history, n=2) == ["hello", "world", "how"]


def test_returns_only_agreed_prefix():
    history = [
        ["hello", "world", "WRONG"],
        ["hello", "world", "how"],
    ]
    assert longest_agreed_prefix(history, n=2) == ["hello", "world"]


def test_n3_requires_three_way_agreement():
    history = [
        ["a", "b", "c"],
        ["a", "b", "d"],
        ["a", "b", "e"],
    ]
    assert longest_agreed_prefix(history, n=3) == ["a", "b"]


def test_uses_only_last_n_when_history_longer():
    history = [
        ["x", "y", "z"],         # this entry should be ignored at n=2
        ["a", "b", "c"],
        ["a", "b", "c"],
    ]
    assert longest_agreed_prefix(history, n=2) == ["a", "b", "c"]


def test_returns_empty_when_first_token_diverges():
    history = [["yes"], ["no"]]
    assert longest_agreed_prefix(history, n=2) == []
