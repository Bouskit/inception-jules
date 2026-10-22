LOGIN = bboukach
DATA_DIR = /home/$(LOGIN)/data
COMPOSE = docker compose -f srcs/docker-compose.yml
COMPOSE_BONUS = $(COMPOSE) --profile bonus

export BUILDX_NO_DEFAULT_ATTESTATIONS :=1

all: up

up:
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	$(COMPOSE) up -d --build

bonus:
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress $(DATA_DIR)/backups
	$(COMPOSE_BONUS) up -d --build
	$(COMPOSE_BONUS) restart wordpress

down:
	$(COMPOSE_BONUS) down

start:
	$(COMPOSE_BONUS) start

stop:
	$(COMPOSE_BONUS) stop

clean: down

fclean:
	$(COMPOSE_BONUS) down -v --rmi all
	sudo rm -rf $(DATA_DIR)

re: fclean all

ps: 
	$(COMPOSE_BONUS) ps

logs: 
	$(COMPOSE_BONUS) logs

.PHONY: all up bonus down start stop clean fclean re ps logs