init:
	cp .env.example .env
	cp .aws/credentials.example .aws/credentials

build:
	docker compose build
rebuild:
	docker compose up -d --build
up:
	docker compose up -d
down:
	docker compose down
destroy:
	docker compose down --rmi all --volumes --remove-orphans
logs:
	docker compose logs -f
ls:
	docker compose ls
terraform:
	docker compose exec terraform bash

# Terraform実行コマンド
%-init:
	docker compose exec terraform terraform -chdir=./$* init
%-plan:
	docker compose exec terraform terraform -chdir=./$* plan
%-apply:
	docker compose exec terraform terraform -chdir=./$* apply
%-refresh:
	docker compose exec terraform terraform -chdir=./$* refresh
%-destroy:
	docker compose exec terraform terraform -chdir=./$* destroy