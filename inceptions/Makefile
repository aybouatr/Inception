USER        := $(shell whoami)
DATA_DIR    := /home/$(USER)/data
COMPOSE     := docker compose -f srcs/docker-compose.yml

all: setup
	$(COMPOSE) up -d --build

setup:
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	grep -qxF "127.0.0.1 aybouatr.42.fr" /etc/hosts || \
		echo "127.0.0.1 aybouatr.42.fr" | sudo tee -a /etc/hosts

down:
	$(COMPOSE) down -v

clean: down
	docker system prune -af
# 	docker system prune -af --volumes
	sudo rm -rf $(DATA_DIR)

re: clean all

.PHONY: all setup down clean re