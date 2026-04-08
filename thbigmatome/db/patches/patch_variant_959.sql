-- db/patches/patch_variant_959.sql
-- subtask_959a: 50件バリアントカードのvariant設定＋元選手紐づけ
--
-- 対象: PM2026 カードセット 50件
-- うち11件は subtask_957b で既に設定済み → スキップ（コメントのみ）
-- 残り39件を本パッチで設定
--
-- 特記: PC378 (アリス・M) のみ player_id を 315→7 (アリス・マーガトロイド) に変更
--
-- 実行方法:
--   docker compose exec -T db psql -U morinaga thbigmatome_development \
--     < db/patches/patch_variant_959.sql
--
-- 生成日: 2026-04-08

BEGIN;

-- ================================================================
-- 既設定11件（subtask_957bで設定済み。参考のみ、UPDATE不要）
-- ================================================================
-- PC331: ヘカーティア・ラピスラズリ, ポートランド, player_id=125 ← 設定済み
-- PC359: スターサファイア, 妖精, player_id=143 ← 設定済み
-- PC362: 少名 針妙丸, 霧島, player_id=4 ← 設定済み
-- PC366: 純狐, 浜宮, player_id=122 ← 設定済み
-- PC367: サリエル, 浜宮2, player_id=113 ← 設定済み
-- PC368: 天弓 千亦, 草津, player_id=20 ← 設定済み
-- PC369: 夢子, 柴又, player_id=127 ← 設定済み
-- PC371: 近藤 咲, 桜木町, player_id=171 ← 設定済み
-- PC373: 蘇我 屠自古, 下関, player_id=5 ← 設定済み
-- PC388: 洩矢 諏訪子, 茨木, player_id=40 ← 設定済み
-- PC390: 小悪魔, 時津, player_id=147 ← 設定済み

-- ================================================================
-- 新規設定39件
-- ================================================================

-- 有原 翼 (UR) → player_id=163 (有原 翼) 維持
UPDATE player_cards SET variant = 'UR' WHERE id = 391;

-- 野崎 夕姫 (筑波) → player_id=164 (野崎 夕姫) 維持
UPDATE player_cards SET variant = '筑波' WHERE id = 365;

-- 寅丸 星 (保土ヶ谷) → player_id=100 (寅丸 星) 維持
UPDATE player_cards SET variant = '保土ヶ谷' WHERE id = 383;

-- 博麗 霊夢 (S&F) → player_id=2 (博麗 霊夢) 維持
UPDATE player_cards SET variant = 'S&F' WHERE id = 356;

-- 中野 綾香 (UR) → player_id=168 (中野 綾香) 維持
UPDATE player_cards SET variant = 'UR' WHERE id = 394;

-- アリス・M (横須賀) → player_id: 315→7 (アリス・マーガトロイド)
UPDATE player_cards SET variant = '横須賀', player_id = 7 WHERE id = 378;

-- 本庄 千景 (UR) → player_id=170 (本庄 千景) 維持
UPDATE player_cards SET variant = 'UR' WHERE id = 399;

-- チルノ (エイプリル) → player_id=23 (チルノ) 維持
UPDATE player_cards SET variant = 'エイプリル' WHERE id = 350;

-- 新田 美奈子 (UR) → player_id=173 (新田 美奈子) 維持
UPDATE player_cards SET variant = 'UR' WHERE id = 392;

-- 比那名居 天子 (エイプリル) → player_id=29 (比那名居 天子) 維持
UPDATE player_cards SET variant = 'エイプリル' WHERE id = 344;

-- 八雲 紫 (筑紫野) → player_id=142 (八雲 紫) 維持
UPDATE player_cards SET variant = '筑紫野' WHERE id = 375;

-- 永江 衣玖 (最上川) → player_id=46 (永江 衣玖) 維持
UPDATE player_cards SET variant = '最上川' WHERE id = 352;

-- 椎名 ゆかり (那珂川) → player_id=188 (椎名 ゆかり) 維持
UPDATE player_cards SET variant = '那珂川' WHERE id = 325;

-- 綿月 豊姫 (須弥山) → player_id=58 (綿月 豊姫) 維持
UPDATE player_cards SET variant = '須弥山' WHERE id = 385;

-- 塚原 雫 (UR) → player_id=192 (塚原 雫) 維持
UPDATE player_cards SET variant = 'UR' WHERE id = 400;

-- 鈴仙・優曇華院・イナバ (エイプリル) → player_id=71 (鈴仙・優曇華院・イナバ) 維持
UPDATE player_cards SET variant = 'エイプリル' WHERE id = 349;

-- 魂魄 妖夢 (幽冥) → player_id=160 (魂魄 妖夢) 維持
UPDATE player_cards SET variant = '幽冥' WHERE id = 338;

-- 射命丸 文 (博多) → player_id=50 (射命丸 文) 維持
UPDATE player_cards SET variant = '博多' WHERE id = 376;

-- 東風谷 早苗 (エイプリル) → player_id=35 (東風谷 早苗) 維持
UPDATE player_cards SET variant = 'エイプリル' WHERE id = 354;

-- 因幡 てゐ (茨城) → player_id=72 (因幡 てゐ) 維持
UPDATE player_cards SET variant = '茨城' WHERE id = 363;

-- 洩矢 諏訪子 (天地人) → player_id=40 (洩矢 諏訪子) 維持
UPDATE player_cards SET variant = '天地人' WHERE id = 357;

-- 藤原 妹紅 (信楽) → player_id=74 (藤原 妹紅) 維持
UPDATE player_cards SET variant = '信楽' WHERE id = 328;

-- 古明地 こいし (茨城) → player_id=91 (古明地 こいし) 維持
UPDATE player_cards SET variant = '茨城' WHERE id = 364;

-- 神宮寺 小也香 (五所川原) → player_id=212 (神宮寺 小也香) 維持
UPDATE player_cards SET variant = '五所川原' WHERE id = 386;

-- 藤堂 たいら (UR) → player_id=215 (藤堂 たいら) 維持
UPDATE player_cards SET variant = 'UR' WHERE id = 401;

-- 明羅 (エイプリル) → player_id=131 (明羅) 維持
UPDATE player_cards SET variant = 'エイプリル' WHERE id = 342;

-- 潮見 凪沙 (伏見) → player_id=218 (潮見 凪沙) 維持
UPDATE player_cards SET variant = '伏見' WHERE id = 377;

-- リグル・ナイトバグ (エイプリル) → player_id=155 (リグル・ナイトバグ) 維持
UPDATE player_cards SET variant = 'エイプリル' WHERE id = 355;

-- 魅魔 (エイプリル) → player_id=109 (魅魔) 維持
UPDATE player_cards SET variant = 'エイプリル' WHERE id = 340;

-- 鬼人 正邪 (エイプリル) → player_id=103 (鬼人 正邪) 維持
UPDATE player_cards SET variant = 'エイプリル' WHERE id = 351;

-- 霊烏路 空 (地底) → player_id=106 (霊烏路 空) 維持
UPDATE player_cards SET variant = '地底' WHERE id = 358;

-- 鎌部 千秋 (東京ベイ) → player_id=240 (鎌部 千秋) 維持
UPDATE player_cards SET variant = '東京ベイ' WHERE id = 387;

-- 真白 玲 (UR) → player_id=244 (真白 玲) 維持
UPDATE player_cards SET variant = 'UR' WHERE id = 402;

-- 摩多羅 隠岐奈 (天保山) → player_id=65 (摩多羅 隠岐奈) 維持
UPDATE player_cards SET variant = '天保山' WHERE id = 333;

-- 坂田 ネムノ (安曇野) → player_id=32 (坂田 ネムノ) 維持
UPDATE player_cards SET variant = '安曇野' WHERE id = 326;

-- 今泉 影狼 (下館) → player_id=73 (今泉 影狼) 維持
UPDATE player_cards SET variant = '下館' WHERE id = 332;

-- 菅牧 典 (小牧) → player_id=44 (菅牧 典) 維持
UPDATE player_cards SET variant = '小牧' WHERE id = 327;

-- 依神 女苑 (旧) → player_id=139 (依神 女苑) 維持
UPDATE player_cards SET variant = '旧' WHERE id = 403;

-- 依神 紫苑 (旧) → player_id=140 (依神 紫苑) 維持
UPDATE player_cards SET variant = '旧' WHERE id = 379;

COMMIT;
