-- ============================================================================
-- v0.3.1 本番カード登録SQL
-- 対象: PM2026 未登録カード4件
-- 実行環境: 本番 thbigmatome_production DB
-- 実行方法: docker exec projects-db-1 psql -U thbigmatome -d thbigmatome_production < v0.3.1_card_registration.sql
-- べき等: ON CONFLICT DO NOTHING により重複実行しても安全
-- ============================================================================

DO $$
DECLARE
  v_card_set_id bigint;
  v_player_yuyu    bigint;  -- 西行寺幽々子 (base touhou)
  v_player_ran     bigint;  -- 八雲藍 (base touhou)
  v_player_hanayama bigint; -- 花山栄美 (hachinai)
  v_player_kotori  bigint;  -- 小鳥遊柚 (hachinai)
  v_now timestamp := NOW();
BEGIN
  -- ── カードセット PM2026 取得 ────────────────────────────────────────────
  SELECT id INTO STRICT v_card_set_id FROM card_sets WHERE name = 'PM2026';

  -- ── プレイヤーID取得（全角/半角スペース正規化） ─────────────────────────
  -- 西行寺幽々子: variant=楼閣 → base touhouプレイヤーのplayer_idを使用
  SELECT id INTO STRICT v_player_yuyu FROM players
    WHERE REPLACE(REPLACE(name, ' ', ''), '　', '') = '西行寺幽々子'
      AND series = 'touhou'
    LIMIT 1;

  -- 八雲藍: variant=WBC2 → base touhouプレイヤーのplayer_idを使用
  SELECT id INTO STRICT v_player_ran FROM players
    WHERE REPLACE(REPLACE(name, ' ', ''), '　', '') = '八雲藍'
      AND series = 'touhou'
    LIMIT 1;

  -- 花山栄美: variant=UR → hachinaiプレイヤーのplayer_idを使用
  SELECT id INTO STRICT v_player_hanayama FROM players
    WHERE REPLACE(REPLACE(name, ' ', ''), '　', '') = '花山栄美'
    LIMIT 1;

  -- 小鳥遊柚: variant=UR → hachinaiプレイヤーのplayer_idを使用
  SELECT id INTO STRICT v_player_kotori FROM players
    WHERE REPLACE(REPLACE(name, ' ', ''), '　', '') = '小鳥遊柚'
    LIMIT 1;

  -- ── 1. 西行寺幽々子（楼閣）─────────────────────────────────────────────
  INSERT INTO player_cards (
    card_set_id, player_id, card_type, variant,
    is_pitcher, is_dual_wielder, is_switch_hitter, is_relief_only, is_closer,
    handedness, speed, bunt, steal_start, steal_end, injury_rate,
    irc_macro_name, unique_traits, biorhythm_period, biorhythm_date_ranges,
    batting_table, pitching_table,
    created_at, updated_at
  ) VALUES (
    v_card_set_id, v_player_yuyu, 'batter', '楼閣',
    false, false, false, false, false,
    'right_throw/right_bat', 1, 1, 1, 1, 5,
    '00', E'背筋痛20日\n腰痛10日', '穀雨・立夏', '["4/20~5/20"]'::jsonb,
    '[["HR7","HR7","H7","H7","H8"],["HR7","2H8","H9","H8","H9"],["HR7","2H9","2B","H9","G3D"],["HR9","H7a","3B","IH4/G4a","G4a"],["HR8/2H8a","H7","RF","G3a","G6D"],["HR9/2H9","H7","G1a","G4D","F8a"],["2H7a","H8a","G3D","G5a","F9"],["2H7","H8","G3a","G6D","PO"],["2H8","H9a","G4D","G6a","K"],["2H9a","H9","G5D","F7a","K"],["2H9","H7/G5a","G5a","F9","K"],["H7a","LF","G6D","PO","K"],["H7","CF","G6a","BB","K"],["H8a","RF","F7a","BB","K"],["H9a","G4a","F7","BB","K"],["H9","G6D","F8","BB","K"],["2B","F7","F9a","BB","K"],["SS","F8a","PO","BB","K"],["G4D","PO","PO","BB","K"],["UP","UP","UP","UP","UP"]]'::jsonb,
    '{}'::jsonb,
    v_now, v_now
  ) ON CONFLICT DO NOTHING;

  -- ── 2. 八雲藍（WBC2）───────────────────────────────────────────────────
  INSERT INTO player_cards (
    card_set_id, player_id, card_type, variant,
    is_pitcher, is_dual_wielder, is_switch_hitter, is_relief_only, is_closer,
    handedness, speed, bunt, steal_start, steal_end, injury_rate,
    irc_macro_name,
    batting_table, pitching_table,
    created_at, updated_at
  ) VALUES (
    v_card_set_id, v_player_ran, 'batter', 'WBC2',
    false, false, false, false, false,
    'right_throw/right_bat', 4, 1, 5, 10, 6,
    '9',
    '[["HR7","HR7","H8","H7","H9"],["HR8","2H7","IH5/G5f","H8","G3a"],["HR9","2H8","P","H9","G4D"],["HR8/3H8","H7a","2B","G3a","G5D"],["3H9","H7","RF","G4D","G6f"],["2H7a","H8a","G1a","G5a","G6a"],["2H9","H8","G3D","G6f","F7"],["H7a","H9","G4f","F7a","F8a"],["H7","LF","G4a","F7","F9"],["H7","CF","G5D","F8","PO"],["H8a","RF","G6f","F9a","PO"],["H8","G3f","F7a","PO","K"],["H8","G5a","F7","PO","K"],["H9a","G6D","F8a","BB","K"],["H9","F7","F8","BB","K"],["H9","F8a","F9","BB","K"],["3B","F9","PO","BB","K"],["SS","PO","PO","BB","K"],["PO","PO","PO","BB","K"],["UP","UP","UP","UP","UP"]]'::jsonb,
    '{}'::jsonb,
    v_now, v_now
  ) ON CONFLICT DO NOTHING;

  -- ── 3. 花山栄美（UR）───────────────────────────────────────────────────
  INSERT INTO player_cards (
    card_set_id, player_id, card_type, variant,
    is_pitcher, is_dual_wielder, is_switch_hitter, is_relief_only, is_closer,
    handedness, speed, bunt, steal_start, steal_end, injury_rate,
    irc_macro_name,
    batting_table, pitching_table,
    created_at, updated_at
  ) VALUES (
    v_card_set_id, v_player_hanayama, 'batter', 'UR',
    false, false, false, false, false,
    'right_throw/right_bat', 5, 4, 8, 15, 4,
    '9',
    '[["HR7","2H9","H9/F9a","IH6","IH5"],["HR9","H7a","2B","G1D","G4D"],["3H9","H7","3B","G3f","G4f"],["3H9/H9a","H7","SS","G4f","G5f"],["2H7","H8a","G1a","G5a","G6a"],["2H8","H8","G3D","G6D","F7"],["H7","H9","G4f","F8","F8a"],["H7","LF","G4a","F9a","PO"],["H8a","CF","G5f","PO","K"],["H8","RF","G6D","BB/G6a","K"],["H8","G3a","G6f","BB","K"],["H9a","G4D","G6a","BB","K"],["H9","G5f","F7","BB","K"],["3B","G6f","F8a","BB","K"],["SS","G6a","F9a","BB","K"],["G4a","F7a","F9","BB","K"],["G5D","F8","PO","BB","K"],["G6f","F9","PO","DB","K"],["F8","PO","K","DB","K"],["UP","UP","UP","UP","UP"]]'::jsonb,
    '{}'::jsonb,
    v_now, v_now
  ) ON CONFLICT DO NOTHING;

  -- ── 4. 小鳥遊柚（UR）───────────────────────────────────────────────────
  INSERT INTO player_cards (
    card_set_id, player_id, card_type, variant,
    is_pitcher, is_dual_wielder, is_switch_hitter, is_relief_only, is_closer,
    handedness, speed, bunt, steal_start, steal_end, injury_rate,
    irc_macro_name,
    batting_table, pitching_table,
    created_at, updated_at
  ) VALUES (
    v_card_set_id, v_player_kotori, 'batter', 'UR',
    false, false, false, false, false,
    'right_throw/right_bat', 3, 1, 4, 12, 5,
    '10',
    '[["HR7","HR7","H7/F7","H8","H7"],["HR7","2H7","3B","G4D","G5D"],["HR7","2H9","SS","G5a","F8"],["HR8","H7a","CF","G6D","PO"],["HR9","H7","G1D","G6f","PO"],["3H9/2H9","H8","G3D","F7a","K"],["2H7","H9a","G4a","F8","K"],["2H8a","LF","G5D","F9","K"],["2H9","CF","G5a","PO","K"],["H7a","RF","G6D","PO","K"],["H7","G5D","F7","PO","K"],["H8a","G6D","F8a","BB","K"],["H9","G6a","F8","BB","K"],["SS","F7","F9a","BB","K"],["CF","F8a","F9","BB","K"],["G5D","F9a","PO","BB","K"],["F8","PO","PO","BB","K"],["PO","PO","PO","DB","K"],["K","K","K","K","K"],["UP","UP","UP","UP","UP"]]'::jsonb,
    '{}'::jsonb,
    v_now, v_now
  ) ON CONFLICT DO NOTHING;

  RAISE NOTICE 'v0.3.1 PM2026カード登録完了（4件: 幽々子楼閣・藍WBC2・栄美UR・柚UR）';
END;
$$;
