# THBIG Dugout Makefile

THBIG_RULES_REPO ?= /home/morinaga/projects/thbig-rules

# ─────────────────────────────────────────────────────────────
# ゲームルール同期
# ─────────────────────────────────────────────────────────────

## sync-rules: thbig-rules の game_rules.yaml を config/game_rules.yaml に同期する
.PHONY: sync-rules
sync-rules:
	@echo "Syncing game_rules.yaml from $(THBIG_RULES_REPO)..."
	@if [ ! -f "$(THBIG_RULES_REPO)/game_rules.yaml" ]; then \
		echo "ERROR: $(THBIG_RULES_REPO)/game_rules.yaml not found"; \
		exit 1; \
	fi
	cp "$(THBIG_RULES_REPO)/game_rules.yaml" config/game_rules.yaml
	@grep '^version:' "$(THBIG_RULES_REPO)/game_rules.yaml" | awk '{print $$2}' | tr -d '"' > config/.game_rules_synced_version
	@echo "Sync complete (version: $$(cat config/.game_rules_synced_version)). Run 'bundle exec rake rules:check' to verify."

## rules-check: ローカルとthbig-rulesのバージョンを照合する（bundle exec rake rules:check の alias）
.PHONY: rules-check
rules-check:
	bundle exec rake rules:check
