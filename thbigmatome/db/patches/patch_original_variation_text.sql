-- db/patches/patch_original_variation_text.sql
-- オリジナル枠選手バリエーションテキスト設定パッチ (cmd_957 / subtask_957b)
--
-- 対象: PM2026 カードでplayer.nameにチーム名/バリエーション名を持つ全カード
-- 処理:
--   1. player_cards.variant = バリエーションテキスト
--   2. player_cards.player_id = ベースプレイヤーのID（初瀬方式: 同一プレイヤー配下に統合）
--
-- 除外: 初瀬 麻里安 (湘南/町田/UR) は既に設定済み (PC380/381/422)
--       冴月 麟 (野手/投手) はベースプレイヤーなし → variant のみ設定
--
-- 実行方法:
--   docker compose exec -T db psql -U postgres thbigmatome_development < db/patches/patch_original_variation_text.sql
--
-- 生成日: 2026-04-08

BEGIN;

-- ================================================================
-- セクション1: チーム名バリエーション (東方・ハチナイ・球詠キャラ)
-- ================================================================

-- 聖 白蓮 (佐世保) → 聖 白蓮 (player_id=84)
UPDATE player_cards SET variant = '佐世保', player_id = 84 WHERE id = 389;

-- 小悪魔 (時津) → 小悪魔 (player_id=147)
UPDATE player_cards SET variant = '時津', player_id = 147 WHERE id = 390;

-- ナズーリン (厚木) → ナズーリン (player_id=102)
UPDATE player_cards SET variant = '厚木', player_id = 102 WHERE id = 334;

-- ヘカーティア・L (ポートランド) → ヘカーティア・ラピスラズリ (player_id=125)
UPDATE player_cards SET variant = 'ポートランド', player_id = 125 WHERE id = 331;

-- スターサファイア (妖精) → スターサファイア (player_id=143)
UPDATE player_cards SET variant = '妖精', player_id = 143 WHERE id = 359;

-- カナ・アナベラル (WBC) → カナ・アナベラル (player_id=116)
UPDATE player_cards SET variant = 'WBC', player_id = 116 WHERE id = 361;

-- 少名 針妙丸 (霧島) → 少名 針妙丸 (player_id=4)
UPDATE player_cards SET variant = '霧島', player_id = 4 WHERE id = 362;

-- 蘇我 屠自古 (下関) → 蘇我 屠自古 (player_id=5)
UPDATE player_cards SET variant = '下関', player_id = 5 WHERE id = 373;

-- サリエル (浜宮2) → サリエル (player_id=113)
UPDATE player_cards SET variant = '浜宮2', player_id = 113 WHERE id = 367;

-- 天弓 千亦 (草津) → 天弓 千亦 (player_id=20)
UPDATE player_cards SET variant = '草津', player_id = 20 WHERE id = 368;

-- 夢子 (柴又) → 夢子 (player_id=127)
UPDATE player_cards SET variant = '柴又', player_id = 127 WHERE id = 369;

-- ナズーリン (多摩) → ナズーリン (player_id=102)
UPDATE player_cards SET variant = '多摩', player_id = 102 WHERE id = 370;

-- 近藤 咲(桜木町) → 近藤 咲 (player_id=171)
UPDATE player_cards SET variant = '桜木町', player_id = 171 WHERE id = 371;

-- 霧雨 魔理沙 (宮崎) → 霧雨 魔理沙 (player_id=3)
UPDATE player_cards SET variant = '宮崎', player_id = 3 WHERE id = 372;

-- エリス (大和) → エリス (player_id=117)
UPDATE player_cards SET variant = '大和', player_id = 117 WHERE id = 382;

-- 我妻 天 (UR) → 我妻 天 (player_id=193)
UPDATE player_cards SET variant = 'UR', player_id = 193 WHERE id = 395;

-- リン・レイファ (UR) → リン・レイファ (player_id=196)
UPDATE player_cards SET variant = 'UR', player_id = 196 WHERE id = 397;

-- 桜田 千代 (UR) → 桜田 千代 (player_id=194)
UPDATE player_cards SET variant = 'UR', player_id = 194 WHERE id = 396;

-- 上白沢 慧音(Ex) → 上白沢 慧音 (player_id=75)
UPDATE player_cards SET variant = 'Ex', player_id = 75 WHERE id = 343;

-- 有原 翼 (里ヶ浜) → 有原 翼 (player_id=163)
UPDATE player_cards SET variant = '里ヶ浜', player_id = 163 WHERE id = 360;

-- 純狐 (浜宮) → 純狐 (player_id=122)
UPDATE player_cards SET variant = '浜宮', player_id = 122 WHERE id = 366;

-- レミリア・スカーレット (都城) → レミリア・スカーレット (player_id=156)
UPDATE player_cards SET variant = '都城', player_id = 156 WHERE id = 374;

-- 洩矢 諏訪子(茨木) → 洩矢 諏訪子 (player_id=40)
UPDATE player_cards SET variant = '茨木', player_id = 40 WHERE id = 388;

-- ================================================================
-- セクション2: 通し番号バリエーション (オリジナルPMプレイヤー)
-- ================================================================

-- マゼラン (2) → マゼラン (player_id=259)
UPDATE player_cards SET variant = '2', player_id = 259 WHERE id = 282;

-- 你 藍翠 (2) → 你 藍翠 (player_id=284)
UPDATE player_cards SET variant = '2', player_id = 284 WHERE id = 291;

-- mori (3) → mori (player_id=257)
UPDATE player_cards SET variant = '3', player_id = 257 WHERE id = 285;

-- かじわら (2) → かじわら (player_id=277)
UPDATE player_cards SET variant = '2', player_id = 277 WHERE id = 289;

-- badferd (2) → badferd (player_id=273)
UPDATE player_cards SET variant = '2', player_id = 273 WHERE id = 290;

-- つばると (2) → つばると (player_id=246)
UPDATE player_cards SET variant = '2', player_id = 246 WHERE id = 295;

-- こりゆの (2) → こりゆの (player_id=282)
UPDATE player_cards SET variant = '2', player_id = 282 WHERE id = 298;

-- Judah (2) → Judah (player_id=266)
UPDATE player_cards SET variant = '2', player_id = 266 WHERE id = 297;

-- 智夜 (2) → 智夜 (player_id=252)
UPDATE player_cards SET variant = '2', player_id = 252 WHERE id = 300;

-- とり (2) → とり (player_id=287)
UPDATE player_cards SET variant = '2', player_id = 287 WHERE id = 303;

-- cyan (2) → cyan (player_id=281)
UPDATE player_cards SET variant = '2', player_id = 281 WHERE id = 305;

-- けいようし (2) → けいようし (player_id=251)
UPDATE player_cards SET variant = '2', player_id = 251 WHERE id = 311;

-- Aal (2) → Aal (player_id=272)
UPDATE player_cards SET variant = '2', player_id = 272 WHERE id = 309;

-- badferd (3) → badferd (player_id=273)
UPDATE player_cards SET variant = '3', player_id = 273 WHERE id = 313;

-- 紫安 (2) → 紫安 (player_id=245)
UPDATE player_cards SET variant = '2', player_id = 245 WHERE id = 284;

-- mori (2) → mori (player_id=257)
UPDATE player_cards SET variant = '2', player_id = 257 WHERE id = 310;

-- つばると (3) → つばると (player_id=246)
UPDATE player_cards SET variant = '3', player_id = 246 WHERE id = 315;

-- ================================================================
-- セクション3: ポジションバリエーション (ベースプレイヤー変更なし)
-- ================================================================

-- 冴月 麟 (野手) - "冴月 麟" ベースプレイヤーなし → player_id 変更なし
UPDATE player_cards SET variant = '野手' WHERE id = 346;

-- 冴月 麟 (投手) - "冴月 麟" ベースプレイヤーなし → player_id 変更なし
UPDATE player_cards SET variant = '投手' WHERE id = 347;

COMMIT;
