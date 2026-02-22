"""pytest test suite for irc_atbat_parser (cmd_286)

Tests:
  - Unit tests for 6 parser fixes (katakana innings, no-half end,
    mismatch detection, sian dice regex, fullwidth score, multi-dice)
  - State machine transition tests (IDLE/GOT_PITCH/AFTER_BAT)
  - Integration regression tests for game2/game5/game8
"""

import sys
import pytest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from irc_atbat_parser import (
    parse_at_bats,
    INNING_END_RE,
    INNING_END_NOHALF_RE,
    SIAN_DICE_RE,
    normalize_score_line,
    kanji_to_int,
    read_log,
)

# ── Constants for integration tests ──────────────────────────────────────────

GAME2_LOG = Path("/mnt/c/Users/necro/Documents/to_team/logs/#thc_BIGbaseball/20250902-IRCnet.txt")
GAME5_LOG = Path("/mnt/c/Users/necro/Documents/to_team/logs/#thc_BIGbaseball/20250905-IRCnet.txt")
GAME8_LOG = Path("/mnt/c/Users/necro/Documents/to_team/logs/#thc_BIGbaseball/20250910-IRCnet.txt")


# ── Helper ────────────────────────────────────────────────────────────────────

def make_lines(*texts):
    """Wrap plain text strings into (fname, lineno, ts, text) tuples."""
    return [("test", i + 1, "", t) for i, t in enumerate(texts)]


def load_game_lines(log_path: Path, start_1indexed: int, end_1indexed: int):
    """Load 1-indexed line range as game_lines tuples."""
    rows = read_log(log_path)
    fname = log_path.name
    return [
        (fname, start_1indexed + i, ts, text)
        for i, (ts, text) in enumerate(rows[start_1indexed - 1:end_1indexed])
    ]


# ── Fix 1: カタカナイニング表記の認識 ────────────────────────────────────────

def test_katakana_inning_omote():
    """「N回オモテ終了」が INNING_END_RE で認識されること"""
    m = INNING_END_RE.search("1回オモテ終了")
    assert m is not None
    assert kanji_to_int(m.group(1)) == 1
    assert m.group(2) == "オモテ"


def test_katakana_inning_ura():
    """「N回ウラ終了」が INNING_END_RE で認識されること"""
    m = INNING_END_RE.search("1回ウラ終了")
    assert m is not None
    assert kanji_to_int(m.group(1)) == 1
    assert m.group(2) == "ウラ"


# ── Fix 2: 半表記なしイニング終了 ───────────────────────────────────────────

def test_inning_end_without_half():
    """「N回終了」が INNING_END_NOHALF_RE で認識され、INNING_END_RE には非マッチ"""
    m_full = INNING_END_RE.search("3回終了")
    assert m_full is None

    m_nohalf = INNING_END_NOHALF_RE.search("3回終了")
    assert m_nohalf is not None
    assert kanji_to_int(m_nohalf.group(1)) == 3


# ── Fix 3: イニング番号不一致の検知 ──────────────────────────────────────────

def test_inning_number_mismatch_detection(capsys):
    """表/裏不一致時に WARNING が標準出力に出力されること"""
    # Default state: cur_inning=1, cur_half='top'
    # Feeding "1回裏終了" (bottom) triggers half mismatch
    game_lines = make_lines("(morin) 1回裏終了 0-0")
    parse_at_bats(game_lines, {"game_id": 1})
    captured = capsys.readouterr()
    assert "WARNING" in captured.out
    assert "イニング不一致" in captured.out


# ── Fix 4: sian ダイス正規表現（キャラ名任意化 + 複数ダイス） ──────────────

def test_sian_dice_with_charname():
    """sian ダイス行がキャラ名ありでパースできること"""
    line = "(sian) (atk) Reimu Dice => [7] result:P3"
    m = SIAN_DICE_RE.match(line)
    assert m is not None
    assert m.group(1) == "atk"
    assert m.group(2) == "Reimu"
    assert m.group(3) == "7"
    assert m.group(4) == "P3"


def test_sian_dice_without_charname():
    """sian ダイス行がキャラ名なしでパースできること"""
    line = "(sian0) (morin) Dice => [15] result:H7"
    m = SIAN_DICE_RE.match(line)
    assert m is not None
    assert m.group(1) == "morin"
    assert not m.group(2)  # None when char_name absent
    assert m.group(3) == "15"
    assert m.group(4) == "H7"


def test_sian_dice_multi():
    """sian ダイス行が複数ダイス [N,N] 形式でパースできること"""
    line = "(sian) (player) sakuya Dice => [15,3] result:R1"
    m = SIAN_DICE_RE.match(line)
    assert m is not None
    assert m.group(3) == "15,3"
    # Parser uses first value as roll
    roll = int(m.group(3).split(",")[0])
    assert roll == 15


# ── Fix 5: 全角スコア変換 ─────────────────────────────────────────────────

def test_fullwidth_score_conversion():
    """全角数字が半角に変換されること（全角ダッシュ－はそのまま）
    SCORE_RE が [-－] 両方にマッチするため、ダッシュ変換は不要"""
    assert normalize_score_line("１－１０") == "1－10"
    assert normalize_score_line("０－０") == "0－0"
    assert normalize_score_line("３x－２") == "3x－2"
    # SCORE_RE はダッシュ変換後の文字列でもマッチすること
    import re
    SCORE_RE = re.compile(r'(\d+x?[-－]\d+x?)')
    assert SCORE_RE.search(normalize_score_line("１－１０")) is not None


# ── Fix 6: 複数ダイス蓄積 ────────────────────────────────────────────────

def test_multiple_dice_accumulation():
    """state=2 での追加ダイスが extra_rolls に蓄積されること"""
    game_lines = make_lines(
        "(sian) (atk) Reimu Dice => [5] result:P5",    # state 0→1 (pitch)
        "(sian) (morin) Youmu Dice => [14] result:R2",  # state 1→2 (bat → range check)
        "(sian) (morin) X Dice => [9] result:H8",       # state 2 (extra roll)
        "(morin) 1回表終了 0-1",
    )
    result = parse_at_bats(game_lines, {"game_id": 999})
    assert len(result["innings"]) == 1
    ab = result["innings"][0]["at_bats"][0]
    assert len(ab["extra_rolls"]) == 1
    assert ab["extra_rolls"][0]["roll"] == 9
    assert ab["extra_rolls"][0]["result"] == "H8"


# ── State machine tests ───────────────────────────────────────────────────────

def test_state_idle_to_got_pitch():
    """IDLE → GOT_PITCH: pitch dice で pending が作成されること
    state=1 (GOT_PITCH) のままイニング終了 → pending は確定されず at_bats は空"""
    game_lines = make_lines(
        "(sian) (atk) Reimu Dice => [5] result:P5",  # state 0→1
        "(morin) 1回表終了 0-0",                       # inning end while state=1
    )
    result = parse_at_bats(game_lines, {"game_id": 999})
    assert len(result["innings"]) == 1
    assert len(result["innings"][0]["at_bats"]) == 0


def test_state_got_pitch_to_after_bat():
    """GOT_PITCH → AFTER_BAT: bat dice で at-bat が完成すること"""
    game_lines = make_lines(
        "(sian) (atk) Reimu Dice => [5] result:P5",    # state 0→1
        "(sian) (morin) Youmu Dice => [15] result:H7",  # state 1→2
        "(morin) 1回表終了 0-1",
    )
    result = parse_at_bats(game_lines, {"game_id": 999})
    assert len(result["innings"][0]["at_bats"]) == 1
    ab = result["innings"][0]["at_bats"][0]
    assert ab["pitch_roll"] == 5
    assert ab["pitch_result"] == "P5"
    assert ab["bat_roll"] == 15
    assert ab["bat_result"] == "H7"


def test_state_after_bat_to_idle_on_next_pitch():
    """-p コマンドで finalize_next=True になり、次 pitch dice で新打席が始まること"""
    game_lines = make_lines(
        "(sian) (atk) Reimu Dice => [5] result:P5",    # ab1 pitch
        "(sian) (morin) Youmu Dice => [15] result:H7",  # ab1 bat
        "(morin) sakuya-p",                              # finalize_next=True
        "(sian) (atk) Marisa Dice => [3] result:P2",    # ab1 finalized; ab2 pitch
        "(sian) (morin) Alice Dice => [20] result:UP",  # ab2 bat
        "(morin) 1回表終了 2-0",
    )
    result = parse_at_bats(game_lines, {"game_id": 999})
    assert len(result["innings"][0]["at_bats"]) == 2


def test_finalize_next_flag():
    """finalize_next により次 pitch dice のタイミングで前 at-bat が確定されること"""
    game_lines = make_lines(
        "(sian) (atk) Reimu Dice => [5] result:P5",
        "(sian) (morin) Youmu Dice => [10] result:G4f",
        "(morin) haku-p",                                # finalize_next=True
        "(sian) (atk) Marisa Dice => [2] result:P1",    # triggers finalize
        "(sian) (morin) Alice Dice => [18] result:HR9",
        "(morin) 1回表終了 1-0",
    )
    result = parse_at_bats(game_lines, {"game_id": 999})
    abs_ = result["innings"][0]["at_bats"]
    assert len(abs_) == 2
    assert abs_[0]["bat_result"] == "G4f"
    assert abs_[1]["bat_result"] == "HR9"


def test_extra_rolls_accumulate_and_reset():
    """extra_rolls が state=2 で蓄積され、次 at-bat では空にリセットされること"""
    game_lines = make_lines(
        # At-bat 1 with 2 extra rolls
        "(sian) (atk) Reimu Dice => [5] result:P5",
        "(sian) (morin) Youmu Dice => [14] result:R3",
        "(sian) (morin) X Dice => [6] result:H9",    # extra roll 1
        "(sian) (morin) X Dice => [11] result:3H9",  # extra roll 2
        "(morin) haku-p",
        # At-bat 2 (no extra rolls)
        "(sian) (atk) Marisa Dice => [3] result:P2",
        "(sian) (morin) Alice Dice => [20] result:UP",
        "(morin) 1回表終了 1-0",
    )
    result = parse_at_bats(game_lines, {"game_id": 999})
    abs_ = result["innings"][0]["at_bats"]
    assert len(abs_) == 2
    assert len(abs_[0]["extra_rolls"]) == 2
    assert abs_[1]["extra_rolls"] == []


# ── Integration regression tests ─────────────────────────────────────────────

@pytest.fixture
def game2_lines():
    return load_game_lines(GAME2_LOG, 36, 729)


@pytest.fixture
def game5_lines():
    return load_game_lines(GAME5_LOG, 778, 1401)


@pytest.fixture
def game8_lines():
    return load_game_lines(GAME8_LOG, 346, 1105)


def test_game2_regression(game2_lines):
    """game2 回帰テスト: innings=17, at_bats=70"""
    result = parse_at_bats(game2_lines, {"game_id": 2})
    assert len(result["innings"]) == 17
    total_at_bats = sum(len(inn["at_bats"]) for inn in result["innings"])
    assert total_at_bats == 70


def test_game5_regression(game5_lines):
    """game5 回帰テスト: innings=17, at_bats=70"""
    result = parse_at_bats(game5_lines, {"game_id": 5})
    assert len(result["innings"]) == 17
    total_at_bats = sum(len(inn["at_bats"]) for inn in result["innings"])
    assert total_at_bats == 70


def test_game8_regression(game8_lines):
    """game8 回帰テスト: innings=18, at_bats=83"""
    result = parse_at_bats(game8_lines, {"game_id": 8})
    assert len(result["innings"]) == 18
    total_at_bats = sum(len(inn["at_bats"]) for inn in result["innings"])
    assert total_at_bats == 83
