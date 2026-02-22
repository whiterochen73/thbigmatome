#!/usr/bin/env python3
"""
IRCログをstdinから受け取り、解析結果をJSON形式でstdoutに出力する。
Usage: echo "<log>" | python3 lib/irc_parser/parse_log.py
"""
import sys
import json
sys.path.insert(0, str(__file__.split('/parse_log.py')[0]))
from irc_atbat_parser import parse_at_bats

def main():
    try:
        log_text = sys.stdin.read()
        game_lines = []

        # Convert each line to the format expected by parse_at_bats
        # parse_at_bats expects tuples of (fname, lineno, ts, text)
        # When reading from stdin, we'll use dummy values for fname and lineno
        for line_num, line in enumerate(log_text.splitlines(), 1):
            game_lines.append(('stdin', line_num, '', line))

        game = {"game_id": 0}
        result = parse_at_bats(game_lines, game)
        print(json.dumps(result, ensure_ascii=False))
    except Exception as e:
        error_result = {"error": str(e)}
        print(json.dumps(error_result, ensure_ascii=False))

if __name__ == '__main__':
    main()
