# Be sure to restart your server when you modify this file.

# CVE-2026-66066 (KindaRails2Shell) 対策。Active Storage の画像処理は libvips
# 経由（variant_processor: :vips）で行われており、信頼できない入力からの
# RCE を防ぐため libvips の untrusted operation blocking を有効化する。
# Rails 8.1.3.1 への更新（根本対策）と併用する多層防御であり、この設定単独では代替にならない。
Vips.block_untrusted(true)
