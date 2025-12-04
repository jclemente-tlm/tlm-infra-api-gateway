# Makefile para controlar Docker Compose
# Variables (puedes sobreescribir en la línea de comandos):
#   DC - comando docker compose (por defecto: "docker compose")
#   ENV - ambiente (local, nonprod, prod)

DC ?= docker compose
ENV ?= local
SERVICE ?= kong
SHELL_CMD ?= /bin/sh

# Selección de archivos según el ambiente
ifeq ($(ENV),local)
	FILES = -f docker-compose.yml -f docker-compose.local.yml
else ifeq ($(ENV),nonprod)
	FILES = -f docker-compose.yml -f docker-compose.nonprod.yml
else ifeq ($(ENV),prod)
	FILES = -f docker-compose.yml -f docker-compose.prod.yml
else
	FILES = -f docker-compose.yml -f docker-compose.local.yml
endif

COMPOSE = $(DC) $(FILES)

.PHONY: help start down logs ps restart exec shell start-local start-nonprod start-prod down-local down-nonprod down-prod

help:
	@printf "Uso:\n\n"
	@printf "  make start [ENV=ambiente]   Inicia los contenedores (detached)\n"
	@printf "  make start-local            Inicia ambiente local\n"
	@printf "  make start-nonprod          Inicia ambiente nonprod\n"
	@printf "  make start-prod             Inicia ambiente prod\n"
	@printf "  make down [ENV=ambiente]    Para y elimina los contenedores\n"
	@printf "  make down-local             Para ambiente local\n"
	@printf "  make down-nonprod           Para ambiente nonprod\n"
	@printf "  make down-prod              Para ambiente prod\n"
	@printf "  make logs [SERVICE=nombre]  Muestra logs (-f)\n"
	@printf "  make ps [ENV=ambiente]      Lista contenedores\n"
	@printf "  make restart [ENV=ambiente] Reinicia (down -> start)\n"
	@printf "  make exec SERVICE=nombre CMD='comando'  Ejecuta comando en servicio\n"
	@printf "  make shell [SERVICE=nombre] Abre shell en servicio\n\n"
	@printf "Ambientes disponibles (variable ENV):\n"
	@printf "  local    - Desarrollo local con Postgres (default)\n"
	@printf "  nonprod  - QA/Staging con DB externa\n"
	@printf "  prod     - Producción con DB externa\n\n"
	@printf "Ejemplos:\n"
	@printf "  make start-local        # Inicia ambiente local\n"
	@printf "  make start-nonprod      # Inicia ambiente nonprod\n"
	@printf "  make logs SERVICE=kong  # Muestra logs de Kong\n"
	@printf "  make shell SERVICE=kong # Abre shell en Kong\n"
	@printf "  make exec SERVICE=kong CMD='kong health'\n"

start:
	$(COMPOSE) up -d --remove-orphans

down:
	$(COMPOSE) down --remove-orphans

logs:
	@if [ -z "$(SERVICE)" ]; then \
		$(COMPOSE) logs -f --tail=100; \
	else \
		$(COMPOSE) logs -f --tail=100 $(SERVICE); \
	fi

ps:
	$(COMPOSE) ps

restart:
	$(MAKE) down
	$(MAKE) start

exec:
	@if [ -z "$(CMD)" ]; then \
		echo "Uso: make exec SERVICE=service CMD='comando'"; exit 1; \
	fi
	$(COMPOSE) exec $(SERVICE) sh -c "$(CMD)"

shell:
	$(COMPOSE) exec $(SERVICE) $(SHELL_CMD)

# Alias para iniciar ambientes específicos
start-local:
	@$(MAKE) start ENV=local

start-nonprod:
	@$(MAKE) start ENV=nonprod

start-prod:
	@$(MAKE) start ENV=prod

# Alias para detener ambientes específicos
down-local:
	@$(MAKE) down ENV=local

down-nonprod:
	@$(MAKE) down ENV=nonprod

down-prod:
	@$(MAKE) down ENV=prod
