SHELL := /bin/zsh
.DEFAULT_GOAL := help

KIND_CLUSTER_NAME ?= sequra-platform
KUBE_CONTEXT ?= kind-$(KIND_CLUSTER_NAME)
KIND_CONFIG ?= infra/kind/kind-config.yaml
KUBECTL := kubectl --context $(KUBE_CONTEXT)
CILIUM_VERSION ?= 1.19.1
TERRAGRUNT ?= terragrunt
POSTGRES_LOCAL_PORT ?= 15432
AIRBYTE_API_LOCAL_PORT ?= 18080
AIRBYTE_PIPELINE_PARALLELISM ?= 1

SVC_01_DIR := infra/services/01-namespaces
SVC_02_DIR := infra/services/02-airbyte
SVC_03_DIR := infra/services/03-postgres
SVC_04_DIR := infra/services/04-minio
SVC_05_DIR := infra/services/05-minio-buckets
PIP_AIRBYTE_DIR := pipelines/airbyte

.PHONY: help config kind-up pull pull-images bootstrap install install-platform install-storage install-pipeline validate-all \
	svc-01-init svc-01-validate svc-01-test svc-01-plan svc-01-apply \
	svc-01-destroy \
	svc-02-init svc-02-validate svc-02-test svc-02-plan svc-02-apply \
	svc-02-destroy \
	svc-03-init svc-03-validate svc-03-test svc-03-plan svc-03-apply \
	svc-03-destroy \
	svc-04-init svc-04-validate svc-04-test svc-04-plan svc-04-apply \
	svc-04-destroy \
	svc-05-init svc-05-validate svc-05-test svc-05-plan svc-05-apply \
	svc-05-destroy \
	pipeline-airbyte-init pipeline-airbyte-validate pipeline-airbyte-plan pipeline-airbyte-apply pipeline-airbyte-destroy \
	check-minio-endpoint \
	services-plan-core services-apply-core services-destroy-core \
	services-plan-storage services-apply-storage services-destroy-storage \
	destroy-kind destroy-all nuke-local \
	validate-network show-validate-network port-forward-airbyte generate-bank-demo-data clean

help:
	@printf '%s\n' \
		"Quick Start (recommended)" \
		"  make config                      # review required local variables/passwords" \
		"  make bootstrap                   # kind + Cilium + pre-pull/load required images" \
		"  make install                     # apply services 01 -> 05 (platform + storage)" \
		"  make install-pipeline            # seed demo data + apply Airbyte pipeline" \
		"  make validate-all                # network policy validation" \
		"" \
		"Platform Services" \
		"  make svc-01-init|validate|test|plan|apply   # namespaces" \
		"  make svc-02-init|validate|test|plan|apply   # airbyte" \
		"  make svc-03-init|validate|test|plan|apply   # postgres (install, users/db/schemas/tables, network policy)" \
		"  make services-plan-core          # plan 01 -> 03 using upstream outputs" \
		"  make services-apply-core         # apply 01 -> 03 in order" \
		"  make services-destroy-core       # destroy 03 -> 01 in reverse order" \
		"  make install-platform            # alias: apply services 01 -> 03" \
		"                                   note: svc-02/03 plan requires real outputs from upstream services" \
		"" \
		"Storage Services" \
		"  make svc-04-init|validate|test|plan|apply # minio deployment" \
		"  make svc-05-init|validate|test|plan|apply # minio bucket creation" \
		"  make services-plan-storage       # plan services 04 -> 05" \
		"  make services-apply-storage      # apply services 04 -> 05" \
		"  make services-destroy-storage    # destroy services 05 -> 04" \
		"  make install-storage             # alias: apply services 04 -> 05" \
		"" \
		"Destroy" \
		"  make destroy-all                 # destroy storage and core, then clean local state, leaving kind empty" \
		"  make destroy-kind                # delete the local kind cluster and clean local state" \
		"  make nuke-local                  # force delete kind cluster and local Terraform states (no terraform destroy)" \
		"" \
		"Operations" \
		"  make validate-network            # verify airbyte can reach PostgreSQL and a temporary external namespace cannot" \
		"  make show-validate-network       # print the connectivity validation commands" \
		"  make port-forward-airbyte        # expose the Airbyte UI on localhost:8080" \
		"  make pipeline-airbyte-init|validate|plan|apply|destroy # manage Airbyte pipeline-as-code root (apply uses -parallelism=$(AIRBYTE_PIPELINE_PARALLELISM))" \
		"  make generate-bank-demo-data     # generate demo banking data in PostgreSQL (2 tables)" \
		"  make clean                       # remove local Terraform state and plans under services"

config:
		@printf '%s\n' \
			"Install terragrunt." \
			"Edit infra/services/03-postgres/terragrunt.hcl and set postgresql_admin_password and users[*].password before applying the PostgreSQL service." \
			"Edit infra/services/04-minio/terragrunt.hcl and set root_password before applying the MinIO service." \
			"Edit infra/services/05-minio-buckets/terragrunt.hcl and set bucket_names and MinIO credentials for bucket creation." \
			"svc-05 uses MinIO NodePort at 127.0.0.1:30900 (requires infra/kind/kind-config.yaml applied)." \
			"Keep infra/services/03-postgres/terragrunt.hcl local provider access settings aligned (kube-system namespace and/or allowed_admin_cidrs)." \
			"If infra/kind/kind-config.yaml changes, recreate kind: make destroy-kind && make kind-up" \
			"Optionally export TG_KUBE_CONTEXT to override the default kind-sequra-platform context."

kind-up:
	@if kind get clusters | grep -qx "$(KIND_CLUSTER_NAME)"; then \
		echo "kind cluster $(KIND_CLUSTER_NAME) already exists"; \
	else \
		set -e; \
		if ! kind create cluster --name $(KIND_CLUSTER_NAME) --config $(KIND_CONFIG) --wait 120s; then \
			echo "initial kind cluster creation failed, cleaning partial cluster and retrying once"; \
			kind delete cluster --name $(KIND_CLUSTER_NAME) >/dev/null 2>&1 || true; \
			sleep 2; \
			kind create cluster --name $(KIND_CLUSTER_NAME) --config $(KIND_CONFIG) --wait 120s; \
		fi; \
	fi
	@kind export kubeconfig --name $(KIND_CLUSTER_NAME)
	@kubectl config use-context $(KUBE_CONTEXT) >/dev/null
	@if ! $(KUBECTL) -n kube-system get daemonset cilium >/dev/null 2>&1; then \
		helm repo add cilium https://helm.cilium.io/ >/dev/null; \
		helm upgrade --install cilium cilium --version $(CILIUM_VERSION) --namespace kube-system --repo https://helm.cilium.io/ --set ipam.mode=kubernetes --set operator.replicas=1 --set hubble.relay.enabled=false --set hubble.ui.enabled=false --wait --timeout 5m; \
	fi
	@$(KUBECTL) wait --for=condition=Ready node --all --timeout=120s
	@NODE_COUNT="$$( $(KUBECTL) get nodes --no-headers | wc -l | tr -d ' ' )"; \
	if [[ "$$NODE_COUNT" -ne 3 ]]; then \
		echo "expected 3 ready nodes in $(KIND_CLUSTER_NAME), found $$NODE_COUNT"; \
		exit 1; \
	fi
	@$(KUBECTL) get nodes
	@$(KUBECTL) -n kube-system get daemonset cilium
	@$(KUBECTL) get storageclass

pull: pull-images

bootstrap: pull

pull-images:
	@IMAGES=( \
		"airbyte/airbyte-base-java-image:3.3.7" \
		"airbyte/bootloader:2.0.1" \
		"airbyte/cron:2.0.1" \
		"airbyte/db:2.0.1" \
		"airbyte/server:2.0.1" \
		"airbyte/worker:2.0.1" \
		"airbyte/workload-api-server:2.0.1" \
		"airbyte/workload-init-container:2.0.1" \
		"airbyte/workload-launcher:2.0.1" \
		"temporalio/auto-setup:1.27.2" \
		"minio/minio:RELEASE.2023-11-20T22-40-07Z" \
		"public.ecr.aws/bitnami/minio:2025.7.23-debian-12-r3" \
		"public.ecr.aws/bitnami/minio-object-browser:2.0.2-debian-12-r3" \
		"public.ecr.aws/bitnami/postgresql:17.6.0-debian-12-r6" \
	); \
	for img in $${IMAGES[@]}; do \
		echo "--> docker pull $$img"; \
		docker pull "$$img"; \
	done; \
	for img in $${IMAGES[@]}; do \
		echo "--> kind load docker-image $$img --name $(KIND_CLUSTER_NAME)"; \
		kind load docker-image "$$img" --name $(KIND_CLUSTER_NAME); \
	done

svc-01-init:
	@$(TERRAGRUNT) --working-dir $(SVC_01_DIR) init

svc-01-validate: svc-01-init
	@$(TERRAGRUNT) --working-dir $(SVC_01_DIR) validate

svc-01-test:
	@terraform -chdir=infra/modules/namespaces init -backend=false >/dev/null
	@terraform -chdir=infra/modules/namespaces test

svc-01-plan: kind-up svc-01-validate
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_01_DIR) plan

svc-01-apply: kind-up svc-01-validate
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_01_DIR) apply -auto-approve

svc-01-destroy:
	@if ! kind get clusters | grep -qx "$(KIND_CLUSTER_NAME)"; then \
		echo "kind cluster $(KIND_CLUSTER_NAME) not found; skipping svc-01-destroy"; \
		exit 0; \
	fi
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_01_DIR) destroy -auto-approve

svc-02-init:
	@$(TERRAGRUNT) --working-dir $(SVC_02_DIR) init

svc-02-validate: svc-02-init
	@$(TERRAGRUNT) --working-dir $(SVC_02_DIR) validate

svc-02-test:
	@terraform -chdir=infra/modules/airbyte init -backend=false >/dev/null
	@terraform -chdir=infra/modules/airbyte test

svc-02-plan: kind-up svc-02-validate
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_02_DIR) plan

svc-02-apply: kind-up svc-02-validate
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_02_DIR) apply -auto-approve

svc-02-destroy:
	@if ! kind get clusters | grep -qx "$(KIND_CLUSTER_NAME)"; then \
		echo "kind cluster $(KIND_CLUSTER_NAME) not found; skipping svc-02-destroy"; \
		exit 0; \
	fi
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_02_DIR) destroy -auto-approve
	@kubectl --context $(KUBE_CONTEXT) -n airbyte delete \
		pod,service,statefulset,configmap,secret,serviceaccount,role,rolebinding \
		-l app.kubernetes.io/instance=sequra-airbyte \
		--ignore-not-found >/dev/null
	@kubectl --context $(KUBE_CONTEXT) -n airbyte wait \
		--for=delete pod \
		-l app.kubernetes.io/instance=sequra-airbyte \
		--timeout=60s >/dev/null 2>&1 || true
	@kubectl --context $(KUBE_CONTEXT) -n airbyte delete pod \
		-l app.kubernetes.io/instance=sequra-airbyte \
		--force --grace-period=0 \
		--ignore-not-found >/dev/null 2>&1 || true
	@kubectl --context $(KUBE_CONTEXT) -n airbyte delete pvc \
		-l app.kubernetes.io/instance=sequra-airbyte \
		--ignore-not-found >/dev/null
	@kubectl --context $(KUBE_CONTEXT) -n airbyte delete secret airbyte-auth-secrets \
		--ignore-not-found >/dev/null

svc-03-init:
	@$(TERRAGRUNT) --working-dir $(SVC_03_DIR) init

svc-03-validate: svc-03-init
	@$(TERRAGRUNT) --working-dir $(SVC_03_DIR) validate

svc-03-test:
	@terraform -chdir=infra/modules/postgres-service init -backend=false >/dev/null
	@terraform -chdir=infra/modules/postgres-service test

svc-03-plan: kind-up svc-03-validate
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_03_DIR) plan -- -refresh=false

svc-03-apply: kind-up svc-03-validate
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_03_DIR) apply -auto-approve

svc-03-destroy:
	@if ! kind get clusters | grep -qx "$(KIND_CLUSTER_NAME)"; then \
		echo "kind cluster $(KIND_CLUSTER_NAME) not found; skipping svc-03-destroy"; \
		exit 0; \
	fi
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_03_DIR) destroy -auto-approve

svc-04-init:
	@$(TERRAGRUNT) --working-dir $(SVC_04_DIR) init

svc-04-validate: svc-04-init
	@$(TERRAGRUNT) --working-dir $(SVC_04_DIR) validate

svc-04-test:
	@terraform -chdir=infra/modules/minio init -backend=false >/dev/null
	@terraform -chdir=infra/modules/minio test

svc-04-plan: kind-up svc-04-validate
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_04_DIR) plan

svc-04-apply: kind-up svc-04-validate
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_04_DIR) apply -auto-approve

svc-04-destroy:
	@if ! kind get clusters | grep -qx "$(KIND_CLUSTER_NAME)"; then \
		echo "kind cluster $(KIND_CLUSTER_NAME) not found; skipping svc-04-destroy"; \
		exit 0; \
	fi
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_04_DIR) destroy -auto-approve

svc-05-init:
	@$(TERRAGRUNT) --working-dir $(SVC_05_DIR) init

svc-05-validate: svc-05-init
	@$(TERRAGRUNT) --working-dir $(SVC_05_DIR) validate

svc-05-test:
	@terraform -chdir=infra/modules/minio-buckets init -backend=false >/dev/null
	@terraform -chdir=infra/modules/minio-buckets test

check-minio-endpoint:
	@if nc -z 127.0.0.1 30900 >/dev/null 2>&1; then \
		echo "MinIO endpoint reachable at 127.0.0.1:30900"; \
	else \
		echo "MinIO endpoint is not reachable at 127.0.0.1:30900."; \
		echo "Apply svc-04 and recreate kind if needed: make destroy-kind && make kind-up"; \
		exit 1; \
	fi

svc-05-plan: kind-up svc-05-validate check-minio-endpoint
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_05_DIR) plan

svc-05-apply: kind-up svc-05-validate check-minio-endpoint
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_05_DIR) apply -auto-approve

svc-05-destroy:
	@if ! kind get clusters | grep -qx "$(KIND_CLUSTER_NAME)"; then \
		echo "kind cluster $(KIND_CLUSTER_NAME) not found; skipping svc-05-destroy"; \
		exit 0; \
	fi
	@TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_05_DIR) destroy -auto-approve

pipeline-airbyte-init:
	@$(TERRAGRUNT) --working-dir $(PIP_AIRBYTE_DIR) init

pipeline-airbyte-validate: pipeline-airbyte-init
	@$(TERRAGRUNT) --working-dir $(PIP_AIRBYTE_DIR) validate

pipeline-airbyte-plan: pipeline-airbyte-validate
	@AIRBYTE_NAMESPACE="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_02_DIR) output -raw namespace)"; \
	AIRBYTE_SERVICE="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_02_DIR) output -raw service_name)"; \
	( $(KUBECTL) -n "$$AIRBYTE_NAMESPACE" port-forward "svc/$$AIRBYTE_SERVICE" $(AIRBYTE_API_LOCAL_PORT):8001 >/tmp/sequra-airbyte-pf.log 2>&1 & echo $$! > /tmp/sequra-airbyte-pf.pid ); \
	trap 'kill $$(cat /tmp/sequra-airbyte-pf.pid) >/dev/null 2>&1 || true; rm -f /tmp/sequra-airbyte-pf.pid' EXIT; \
	for i in {1..20}; do nc -z 127.0.0.1 $(AIRBYTE_API_LOCAL_PORT) >/dev/null 2>&1 && break; sleep 1; done; \
	nc -z 127.0.0.1 $(AIRBYTE_API_LOCAL_PORT) >/dev/null 2>&1 || (echo "airbyte api port-forward failed"; cat /tmp/sequra-airbyte-pf.log; exit 1); \
	$(TERRAGRUNT) --working-dir $(PIP_AIRBYTE_DIR) plan

pipeline-airbyte-apply: pipeline-airbyte-validate
	@AIRBYTE_NAMESPACE="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_02_DIR) output -raw namespace)"; \
	AIRBYTE_SERVICE="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_02_DIR) output -raw service_name)"; \
	( $(KUBECTL) -n "$$AIRBYTE_NAMESPACE" port-forward "svc/$$AIRBYTE_SERVICE" $(AIRBYTE_API_LOCAL_PORT):8001 >/tmp/sequra-airbyte-pf.log 2>&1 & echo $$! > /tmp/sequra-airbyte-pf.pid ); \
	trap 'kill $$(cat /tmp/sequra-airbyte-pf.pid) >/dev/null 2>&1 || true; rm -f /tmp/sequra-airbyte-pf.pid' EXIT; \
	for i in {1..20}; do nc -z 127.0.0.1 $(AIRBYTE_API_LOCAL_PORT) >/dev/null 2>&1 && break; sleep 1; done; \
	nc -z 127.0.0.1 $(AIRBYTE_API_LOCAL_PORT) >/dev/null 2>&1 || (echo "airbyte api port-forward failed"; cat /tmp/sequra-airbyte-pf.log; exit 1); \
	$(TERRAGRUNT) --working-dir $(PIP_AIRBYTE_DIR) apply -auto-approve -- -parallelism=$(AIRBYTE_PIPELINE_PARALLELISM)

pipeline-airbyte-destroy:
	@AIRBYTE_NAMESPACE="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_02_DIR) output -raw namespace)"; \
	AIRBYTE_SERVICE="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_02_DIR) output -raw service_name)"; \
	( $(KUBECTL) -n "$$AIRBYTE_NAMESPACE" port-forward "svc/$$AIRBYTE_SERVICE" $(AIRBYTE_API_LOCAL_PORT):8001 >/tmp/sequra-airbyte-pf.log 2>&1 & echo $$! > /tmp/sequra-airbyte-pf.pid ); \
	trap 'kill $$(cat /tmp/sequra-airbyte-pf.pid) >/dev/null 2>&1 || true; rm -f /tmp/sequra-airbyte-pf.pid' EXIT; \
	for i in {1..20}; do nc -z 127.0.0.1 $(AIRBYTE_API_LOCAL_PORT) >/dev/null 2>&1 && break; sleep 1; done; \
	nc -z 127.0.0.1 $(AIRBYTE_API_LOCAL_PORT) >/dev/null 2>&1 || (echo "airbyte api port-forward failed"; cat /tmp/sequra-airbyte-pf.log; exit 1); \
	$(TERRAGRUNT) --working-dir $(PIP_AIRBYTE_DIR) destroy -auto-approve

services-plan-core: svc-01-plan svc-02-plan svc-03-plan

services-apply-core: svc-01-apply svc-02-apply svc-03-apply

services-destroy-core: svc-03-destroy svc-02-destroy svc-01-destroy

services-plan-storage: svc-04-plan svc-05-plan

services-apply-storage: svc-04-apply svc-05-apply

services-destroy-storage: svc-05-destroy svc-04-destroy

install-platform: services-apply-core

install-storage: services-apply-storage

install: install-platform install-storage

install-pipeline: generate-bank-demo-data pipeline-airbyte-apply

validate-all: validate-network

destroy-all: services-destroy-storage services-destroy-core clean

destroy-kind:
	@$(MAKE) destroy-all || true
	@kind delete cluster --name $(KIND_CLUSTER_NAME) || true

nuke-local:
	@kind delete cluster --name $(KIND_CLUSTER_NAME) || true
	@$(MAKE) clean

validate-network:
	@POSTGRES_DNS="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_03_DIR) output -raw internal_dns)"; \
	AIRBYTE_NAMESPACE="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_02_DIR) output -raw namespace)"; \
	DEBUG_NAMESPACE="netcheck-debug"; \
	echo "Running positive connectivity check from namespace $$AIRBYTE_NAMESPACE..."; \
	$(KUBECTL) -n "$$AIRBYTE_NAMESPACE" run netcheck-allow --image=busybox:1.36 --restart=Never --rm -i --command -- sh -ec "nc -zvw5 $$POSTGRES_DNS 5432"; \
	echo "Ensuring temporary namespace $$DEBUG_NAMESPACE exists for the negative test..."; \
	$(KUBECTL) create namespace "$$DEBUG_NAMESPACE" --dry-run=client -o yaml | $(KUBECTL) apply -f - >/dev/null; \
	echo "Running negative connectivity check from namespace $$DEBUG_NAMESPACE..."; \
	$(KUBECTL) -n "$$DEBUG_NAMESPACE" run netcheck-deny-debug --image=busybox:1.36 --restart=Never --rm -i --command -- sh -ec "if nc -zvw5 $$POSTGRES_DNS 5432; then exit 1; fi"; \
	$(KUBECTL) delete namespace "$$DEBUG_NAMESPACE" --ignore-not-found >/dev/null

show-validate-network:
	@POSTGRES_DNS="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_03_DIR) output -raw internal_dns)"; \
	AIRBYTE_NAMESPACE="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_02_DIR) output -raw namespace)"; \
	DEBUG_NAMESPACE="netcheck-debug"; \
	printf '%s\n' \
		"kubectl --context $(KUBE_CONTEXT) -n $$AIRBYTE_NAMESPACE run netcheck-allow --image=busybox:1.36 --restart=Never --rm -i --command -- sh -ec 'nc -zvw5 $$POSTGRES_DNS 5432'" \
		"kubectl --context $(KUBE_CONTEXT) create namespace $$DEBUG_NAMESPACE --dry-run=client -o yaml | kubectl --context $(KUBE_CONTEXT) apply -f -" \
		"kubectl --context $(KUBE_CONTEXT) -n $$DEBUG_NAMESPACE run netcheck-deny-debug --image=busybox:1.36 --restart=Never --rm -i --command -- sh -ec 'if nc -zvw5 $$POSTGRES_DNS 5432; then exit 1; fi'" \
		"kubectl --context $(KUBE_CONTEXT) delete namespace $$DEBUG_NAMESPACE --ignore-not-found"

port-forward-airbyte:
	@AIRBYTE_NAMESPACE="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_02_DIR) output -raw namespace)"; \
	AIRBYTE_SERVICE="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_02_DIR) output -raw service_name)"; \
	$(KUBECTL) -n "$$AIRBYTE_NAMESPACE" port-forward "svc/$$AIRBYTE_SERVICE" 8080:8001

generate-bank-demo-data:
	@POSTGRES_NAMESPACE="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_03_DIR) output -raw namespace)"; \
	POSTGRES_SERVICE="$$(TG_KUBE_CONTEXT=$(KUBE_CONTEXT) $(TERRAGRUNT) --working-dir $(SVC_03_DIR) output -raw service_name)"; \
	( $(KUBECTL) -n "$$POSTGRES_NAMESPACE" port-forward "svc/$$POSTGRES_SERVICE" $(POSTGRES_LOCAL_PORT):5432 >/tmp/sequra-postgres-pf.log 2>&1 & echo $$! > /tmp/sequra-postgres-pf.pid ); \
	trap 'kill $$(cat /tmp/sequra-postgres-pf.pid) >/dev/null 2>&1 || true; rm -f /tmp/sequra-postgres-pf.pid' EXIT; \
	for i in {1..20}; do nc -z 127.0.0.1 $(POSTGRES_LOCAL_PORT) >/dev/null 2>&1 && break; sleep 1; done; \
	nc -z 127.0.0.1 $(POSTGRES_LOCAL_PORT) >/dev/null 2>&1 || (echo "postgres port-forward failed"; cat /tmp/sequra-postgres-pf.log; exit 1); \
	KUBE_CONTEXT="$(KUBE_CONTEXT)" PGHOST=127.0.0.1 PGPORT=$(POSTGRES_LOCAL_PORT) PGUSER=postgres POSTGRES_SECRET_KEY=postgres-password ./scripts/generate_bank_demo_data.sh

clean:
	@rm -rf infra/.terraform
	@rm -rf pipelines/.terraform
	@find infra/services -type d -name .terraform -prune -exec rm -rf {} +
	@find pipelines -type d -name .terraform -prune -exec rm -rf {} +
	@find infra/services -type f \( -name "terraform.tfstate" -o -name "terraform.tfstate.*" -o -name "tfplan" -o -name "crash.log" \) -delete
	@find pipelines -type f \( -name "terraform.tfstate" -o -name "terraform.tfstate.*" -o -name "tfplan" -o -name "crash.log" \) -delete
	@find . -type d -name .terragrunt-cache -prune -exec rm -rf {} +
