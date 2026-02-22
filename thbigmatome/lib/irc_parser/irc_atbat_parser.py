#!/usr/bin/env python3
"""IRC at-bat level parser (Phase 2) for thbig-irc logs.

Usage:
  python3 scripts/irc_atbat_parser.py --game-id 2 --channel 1
  python3 scripts/irc_atbat_parser.py --all --channel 1
  python3 scripts/irc_atbat_parser.py --all --channel 1 --output path/out.json
"""

import re
import json
import argparse
from pathlib import Path

LOG_BASE = Path("/mnt/c/Users/necro/Documents/to_team/logs")
BOUNDARY_FILE = Path("context/irc-game-boundary-results.json")
CHANNELS = [
    "#thc_BIGbaseball",
    "#thc_BIGbaseball2",
    "#thc_BIGbaseball3",
    "#thc_BIGbaseball4",
]

# --- Regex patterns ---
LINE_RE = re.compile(r'^(\d{2}:\d{2}:\d{2}) (.+)$')

# sian bot dice: "(sian) (player) [charname] Dice => [N[,N...]] result:CODE"
SIAN_DICE_RE = re.compile(
    r'^\(sian0?\) \((\w+)\) (?:(.+?) )?Dice => \[(\d+(?:,\d+)*)\] result:(.+)$'
)

# Inning end: "N回表終了" / "N回裏終了" / "N回オモテ終了" / "N回ウラ終了"
INNING_END_RE = re.compile(r'([一二三四五六七八九十]+|\d+)回([表裏]|オモテ|ウラ)終了')

# Inning end without half indicator: "N回終了"
INNING_END_NOHALF_RE = re.compile(r'([一二三四五六七八九十]+|\d+)回終了')

# Score e.g. "0-0", "3x-2", "１－６"
SCORE_RE = re.compile(r'(\d+x?[-－]\d+x?)')

# Pitch macro command: line ending with "-p"
PITCH_CMD_RE = re.compile(r'-p\s*$')

# Events (best-effort)
PITCHER_CHANGE_RE = re.compile(r'に交代|ピッチャー.*交代|P交代|ピッチャーチェンジ')
PINCH_HIT_RE = re.compile(r'代打|PH[\s　]')
PINCH_RUN_RE = re.compile(r'代走|PR[\s　]')

# Generic player line
PLAYER_LINE_RE = re.compile(r'^\((\w+)\) (.+)$')

# Macro/command pattern to exclude from play descriptions
MACRO_RE = re.compile(r'^[\w]+-[p\d]+\s*$')

def normalize_score_line(line: str) -> str:
    """Normalize fullwidth digits to ASCII digits."""
    return line.translate(str.maketrans('０１２３４５６７８９', '0123456789'))


KANJI_NUM = {
    '一': 1, '二': 2, '三': 3, '四': 4, '五': 5,
    '六': 6, '七': 7, '八': 8, '九': 9,
    '十': 10, '十一': 11, '十二': 12,
}


def kanji_to_int(s: str) -> int:
    if s in KANJI_NUM:
        return KANJI_NUM[s]
    try:
        return int(s)
    except ValueError:
        return 0


def read_log(path: Path) -> list:
    """Read log file → list of (timestamp, text) tuples."""
    for enc in ('utf-8-sig', 'utf-8', 'shift_jis'):
        try:
            raw = path.read_text(encoding=enc, errors='replace')
            rows = []
            for line in raw.splitlines():
                m = LINE_RE.match(line.strip())
                if m:
                    rows.append((m.group(1), m.group(2)))
            return rows
        except Exception:
            continue
    return []


def load_channel_lines(channel: str) -> list:
    """Load all filtered lines from a channel directory."""
    ch_dir = LOG_BASE / channel
    all_lines = []
    for f in sorted(ch_dir.glob('*-IRCnet.txt')):
        for i, (ts, text) in enumerate(read_log(f)):
            all_lines.append((f.name, i + 1, ts, text))
    return all_lines


def get_game_slice(all_lines: list, game: dict) -> list:
    """Extract lines belonging to a specific game using boundary data."""
    if not game.get('end_file'):
        return []
    start_file, start_line = game['start_file'], game['start_line']
    end_file, end_line = game['end_file'], game['end_line']
    start_idx = end_idx = None
    for i, (fname, lineno, _ts, _text) in enumerate(all_lines):
        if start_idx is None and fname == start_file and lineno == start_line:
            start_idx = i
        if fname == end_file and lineno == end_line:
            end_idx = i
            break
    if start_idx is None or end_idx is None:
        return []
    return all_lines[start_idx:end_idx + 1]


def parse_at_bats(game_lines: list, game: dict) -> dict:
    """Parse at-bat / inning structure from a game's lines.

    State machine:
      0 = IDLE       (waiting for pitch dice)
      1 = GOT_PITCH  (pitch seen, waiting for bat dice)
      2 = AFTER_BAT  (bat seen, collecting extra rolls / play text)
    """
    innings = []
    pitcher_changes = []
    lineups = {'home': [], 'away': []}
    cur_inning, cur_half = 1, 'top'
    cur_abs, cur_events = [], []
    cur_score = '0-0'
    ab_num = 0

    state = 0       # IDLE
    pending = None  # current at-bat being built
    finalize_next = False  # True when -p cmd seen; next sian dice starts new ab

    for _fname, _lineno, _ts, text in game_lines:

        # --- Inning end marker ---
        im = INNING_END_RE.search(text)
        im_nohalf = None if im else INNING_END_NOHALF_RE.search(text)
        if im or im_nohalf:
            # Finalize any complete pending at-bat
            if pending and state >= 2:
                cur_abs.append(pending)
            pending = None
            state = 0
            finalize_next = False

            game_id = game.get('game_id', '?')
            if im:
                inning_num = kanji_to_int(im.group(1))
                half = 'top' if im.group(2) in ('表', 'オモテ') else 'bottom'
            else:
                inning_num = kanji_to_int(im_nohalf.group(1))
                half = cur_half
                print(f"WARNING: game {game_id} - イニング終了（表/裏なし）: {text}")

            # Desync warning
            if inning_num != cur_inning or half != cur_half:
                expected = f"{cur_inning}回{'表' if cur_half == 'top' else '裏'}"
                detected = f"{inning_num}回{'表' if half == 'top' else '裏'}"
                print(f"WARNING: game {game_id} - イニング不一致: 期待={expected}, 検出={detected}")

            sm = SCORE_RE.search(normalize_score_line(text))
            cur_score = sm.group(1) if sm else cur_score

            innings.append({
                'inning': cur_inning,
                'half': cur_half,
                'at_bats': cur_abs,
                'events': cur_events,
                'score_after': cur_score,
            })
            cur_abs, cur_events = [], []

            # Advance to next half-inning
            cur_inning = inning_num
            cur_half = 'bottom' if half == 'top' else 'top'
            if half == 'bottom':
                cur_inning = inning_num + 1
            continue

        # --- sian bot dice response ---
        dm = SIAN_DICE_RE.match(text)
        if dm:
            player = dm.group(1)
            char_name = dm.group(2).strip() if dm.group(2) else ''
            roll = int(dm.group(3).split(',')[0])
            result = dm.group(4).strip()

            if state == 0 or finalize_next:
                # Start a new at-bat (finalize previous if any)
                if finalize_next and pending and state >= 2:
                    cur_abs.append(pending)
                ab_num += 1
                pending = {
                    'ab_num': ab_num,
                    'pitcher_player': player,
                    'pitcher_name': char_name,
                    'batter_player': '',
                    'batter_name': '',
                    'pitch_roll': roll,
                    'pitch_result': result,
                    'bat_roll': None,
                    'bat_result': '',
                    'extra_rolls': [],
                    'play_description': '',
                }
                state = 1
                finalize_next = False

            elif state == 1:
                # Bat dice
                pending['batter_player'] = player
                pending['batter_name'] = char_name
                pending['bat_roll'] = roll
                pending['bat_result'] = result
                state = 2

            elif state == 2:
                # Extra roll (range check, UP table, etc.)
                pending['extra_rolls'].append({
                    'player': player,
                    'roll': roll,
                    'result': result,
                })
            continue

        # --- Non-bot player lines ---
        pm = PLAYER_LINE_RE.match(text)
        if not pm:
            continue
        speaker = pm.group(1)
        body = pm.group(2).strip()

        # Pitch command detection → next sian dice starts a new at-bat
        if state == 2 and PITCH_CMD_RE.search(body):
            finalize_next = True

        # Play description capture (first natural-language line after bat)
        if state == 2 and pending and not pending['play_description']:
            if not MACRO_RE.match(body):
                pending['play_description'] = body

        # Event detection (best-effort)
        if PITCHER_CHANGE_RE.search(body):
            cur_events.append({'type': 'pitcher_change', 'speaker': speaker, 'text': body})
            pitcher_changes.append({
                'inning': cur_inning, 'half': cur_half,
                'speaker': speaker, 'text': body,
            })
        if PINCH_HIT_RE.search(body):
            cur_events.append({'type': 'pinch_hit', 'speaker': speaker, 'text': body})
        if PINCH_RUN_RE.search(body):
            cur_events.append({'type': 'pinch_run', 'speaker': speaker, 'text': body})

    # Finalize any remaining at-bat at game end
    if pending and state >= 2:
        cur_abs.append(pending)
    if cur_abs or cur_events:
        innings.append({
            'inning': cur_inning,
            'half': cur_half,
            'at_bats': cur_abs,
            'events': cur_events,
            'score_after': cur_score,
        })

    return {
        'game_id': game['game_id'],
        'channel': '',
        'innings': innings,
        'lineups': lineups,
        'pitcher_changes': pitcher_changes,
        'final_score': game.get('final_score', ''),
    }


def main():
    parser = argparse.ArgumentParser(description='IRC at-bat level parser (Phase 2)')
    parser.add_argument('--game-id', type=int, help='Specific game ID to parse')
    parser.add_argument('--channel', type=int, choices=[1, 2, 3, 4],
                        required=True, help='Channel number (1-4)')
    parser.add_argument('--all', action='store_true', help='Parse all games in channel')
    parser.add_argument('--output', help='Output JSON file path')
    parser.add_argument('--boundary', default=str(BOUNDARY_FILE),
                        help='Path to boundary results JSON')
    args = parser.parse_args()

    if not args.game_id and not args.all:
        parser.error('Specify --game-id N or --all')

    boundary_path = Path(args.boundary)
    if not boundary_path.exists():
        print(f'ERROR: boundary file not found: {boundary_path}')
        return
    with open(boundary_path, encoding='utf-8') as f:
        boundary_data = json.load(f)

    channel = CHANNELS[args.channel - 1]
    if isinstance(boundary_data, list):
        ch_data = next((x for x in boundary_data if x['channel'] == channel), None)
    else:
        ch_data = boundary_data if boundary_data.get('channel') == channel else None
    if not ch_data:
        print(f'ERROR: channel {channel} not found in boundary data')
        return

    games = ch_data.get('games', [])
    if not games:
        print('No games found')
        return

    if args.game_id:
        games = [g for g in games if g['game_id'] == args.game_id]
        if not games:
            print(f'ERROR: game_id {args.game_id} not found')
            return

    print(f'Loading channel {channel} logs...')
    all_lines = load_channel_lines(channel)
    print(f'  Loaded {len(all_lines)} lines from {channel}')

    results = []
    for game in games:
        gid = game['game_id']
        print(f'  Parsing game {gid} ({game.get("final_score", "?")})...')
        game_lines = get_game_slice(all_lines, game)
        if not game_lines:
            print(f'    WARNING: no lines found for game {gid}')
            results.append({'game_id': gid, 'error': 'no_lines'})
            continue
        result = parse_at_bats(game_lines, game)
        result['channel'] = channel
        total_abs = sum(len(inn['at_bats']) for inn in result.get('innings', []))
        n_innings = len(result.get('innings', []))
        print(f'    innings={n_innings} at_bats={total_abs}')
        results.append(result)

    output = results[0] if len(results) == 1 else results

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            json.dump(output, f, ensure_ascii=False, indent=2)
        print(f'Saved to {args.output}')
    else:
        data = output if isinstance(output, dict) else output[0]
        preview = json.dumps(data, ensure_ascii=False, indent=2)
        if len(preview) > 4000:
            preview = preview[:4000] + '\n... (truncated)'
        print('\n--- Preview ---')
        print(preview)


if __name__ == '__main__':
    main()
