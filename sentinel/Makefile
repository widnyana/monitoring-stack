RED = \033[31m
RESET = \033[0m

clean:
	@clear
	@read -p "$(shell echo -e "$(RED) [!] This action will break lots of things;\nAre you fucking sure? [y/n]: $(RESET)")" answer; \
	if echo "$$answer" | grep -iq "^y"; then \
		echo " [!] performing clean-up"; \
		rm -f configs/postgresql/17/.env.pg17-*; \
		rm -f configs/.initialized; \
		sudo rm -fr "./data"; \
		git checkout -- .; \
	else \
		echo " [+] good catch, doing nothing..."; \
	fi

init:
	@echo "Creating data directory..."
	@mkdir -p \
		./data/prometheus \
		./data/grafana \
		./data/letsencrypt \
		./data/nginx-proxy-manager \
		./data/postgresql17-data
	@bash ./scripts/init.sh
