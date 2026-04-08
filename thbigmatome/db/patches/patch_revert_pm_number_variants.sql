-- db/patches/patch_revert_pm_number_variants.sql
-- subtask_957e: PMカード（通し番号選手）への誤variant付与を修正
--
-- 問題: subtask_957b で マゼラン(2)・mori(3) 等の PM オリジナル選手カードに
--        variant='2'/'3' と player_id をベースプレイヤーへ変更してしまった。
--        これらは「別選手」扱いのため variant 不要。
--
-- 修正: variant を NULL に戻し、player_id を元の選手（名前に番号を含む）に戻す。
--
-- 実行方法:
--   docker compose exec -T db psql -U morinaga thbigmatome_development \
--     < db/patches/patch_revert_pm_number_variants.sql
--
-- 生成日: 2026-04-08

BEGIN;

-- マゼラン (2) → player_id=247
UPDATE player_cards SET variant = NULL, player_id = 247 WHERE id = 282;

-- 紫安 (2) → player_id=249
UPDATE player_cards SET variant = NULL, player_id = 249 WHERE id = 284;

-- mori (3) → player_id=250
UPDATE player_cards SET variant = NULL, player_id = 250 WHERE id = 285;

-- かじわら (2) → player_id=254
UPDATE player_cards SET variant = NULL, player_id = 254 WHERE id = 289;

-- badferd (2) → player_id=255
UPDATE player_cards SET variant = NULL, player_id = 255 WHERE id = 290;

-- 你 藍翠 (2) → player_id=256
UPDATE player_cards SET variant = NULL, player_id = 256 WHERE id = 291;

-- つばると (2) → player_id=260
UPDATE player_cards SET variant = NULL, player_id = 260 WHERE id = 295;

-- Judah (2) → player_id=262
UPDATE player_cards SET variant = NULL, player_id = 262 WHERE id = 297;

-- こりゆの (2) → player_id=263
UPDATE player_cards SET variant = NULL, player_id = 263 WHERE id = 298;

-- 智夜 (2) → player_id=265
UPDATE player_cards SET variant = NULL, player_id = 265 WHERE id = 300;

-- とり (2) → player_id=268
UPDATE player_cards SET variant = NULL, player_id = 268 WHERE id = 303;

-- cyan (2) → player_id=270
UPDATE player_cards SET variant = NULL, player_id = 270 WHERE id = 305;

-- Aal (2) → player_id=274
UPDATE player_cards SET variant = NULL, player_id = 274 WHERE id = 309;

-- mori (2) → player_id=275
UPDATE player_cards SET variant = NULL, player_id = 275 WHERE id = 310;

-- けいようし (2) → player_id=276
UPDATE player_cards SET variant = NULL, player_id = 276 WHERE id = 311;

-- badferd (3) → player_id=278
UPDATE player_cards SET variant = NULL, player_id = 278 WHERE id = 313;

-- つばると (3) → player_id=280
UPDATE player_cards SET variant = NULL, player_id = 280 WHERE id = 315;

COMMIT;
