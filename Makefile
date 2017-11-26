AIRFLOW_VERSION ?= 1.8.0.0
KUBECTL_VERSION ?= 1.6.1
KUBE_AIRFLOW_VERSION ?= 0.10

REPOSITORY ?= mumoshu/kube-airflow
TAG ?= $(AIRFLOW_VERSION)-$(KUBECTL_VERSION)-$(KUBE_AIRFLOW_VERSION)
IMAGE ?= $(REPOSITORY):$(TAG)
ALIAS ?= $(REPOSITORY):$(AIRFLOW_VERSION)-$(KUBECTL_VERSION)

BUILD_ROOT ?= build/$(TAG)
DOCKERFILE ?= $(BUILD_ROOT)/Dockerfile
ROOTFS ?= $(BUILD_ROOT)/rootfs
AIRFLOW_CONF ?= $(BUILD_ROOT)/config/airflow.cfg
ENTRYPOINT_SH ?= $(BUILD_ROOT)/script/entrypoint.sh
GIT_SYNC ?= $(BUILD_ROOT)/script/git-sync
DAGS ?= $(BUILD_ROOT)/dags
AIRFLOW_REQUIREMENTS ?= $(BUILD_ROOT)/requirements/airflow.txt
DAGS_REQUIREMENTS ?= $(BUILD_ROOT)/requirements/dags.txt
DOCKER_CACHE ?= docker-cache
SAVED_IMAGE ?= $(DOCKER_CACHE)/image-$(AIRFLOW_VERSION)-$(KUBECTL_VERSION).tar

NAMESPACE ?= airflow-dev
HELM_APPLICATION_NAME ?= airflow
HELM_VALUES ?= airflow/values.yaml
CHART_LOCATION ?= ./airflow
EMBEDDED_DAGS_LOCATION ?= "./dags"
REQUIREMENTS_TXT_LOCATION ?= "requirements/dags.txt"

.PHONY: build clean

clean:
	rm -Rf build

helm-install:
	helm upgrade -f $(HELM_VALUES) \
	             --install \
	             --debug \
	             $(HELM_APPLICATION_NAME) \
	             $(CHART_LOCATION)

helm-check:
	helm install --dry_run \
	            $(CHART_LOCATION) \
	             --version=v0.1.0 \
	             --name=$(HELM_APPLICATION_NAME) \
	             --namespace=$(NAMESPACE) \
	             --debug \
	             -f $(HELM_VALUES)

helm-ls:
	helm ls --all $(HELM_APPLICATION_NAME)

helm-uninstall:
	helm del --purge $(HELM_APPLICATION_NAME)

build: clean $(DOCKERFILE) $(ROOTFS) $(DAGS) $(AIRFLOW_CONF) $(ENTRYPOINT_SH) $(GIT_SYNC) $(AIRFLOW_REQUIREMENTS) $(DAGS_REQUIREMENTS)
	cd $(BUILD_ROOT) && docker build -t $(IMAGE) . && docker tag $(IMAGE) $(ALIAS)

publish:
	docker push $(IMAGE) && docker push $(ALIAS)

$(DOCKERFILE): $(BUILD_ROOT)
	sed -e 's/%%KUBECTL_VERSION%%/'"$(KUBECTL_VERSION)"'/g;' \
	    -e 's/%%AIRFLOW_VERSION%%/'"$(AIRFLOW_VERSION)"'/g;' \
	    -e 's#%%EMBEDDED_DAGS_LOCATION%%#'"$(EMBEDDED_DAGS_LOCATION)"'#g;' \
	    -e 's#%%REQUIREMENTS_TXT_LOCATION%%#'"$(REQUIREMENTS_TXT_LOCATION)"'#g;' \
	    Dockerfile.template > $(DOCKERFILE)

$(ROOTFS): $(BUILD_ROOT)
	mkdir -p rootfs
	cp -R rootfs $(ROOTFS)

$(AIRFLOW_CONF): $(BUILD_ROOT)
	mkdir -p $(shell dirname $(AIRFLOW_CONF))
	cp config/airflow.cfg $(AIRFLOW_CONF)

$(ENTRYPOINT_SH): $(BUILD_ROOT)
	mkdir -p $(shell dirname $(ENTRYPOINT_SH))
	cp script/entrypoint.sh $(ENTRYPOINT_SH)

$(GIT_SYNC): $(BUILD_ROOT)
	mkdir -p $(shell dirname $(GIT_SYNC))
	cp script/git-sync $(GIT_SYNC)

$(AIRFLOW_REQUIREMENTS): $(BUILD_ROOT)
	mkdir -p $(shell dirname $(AIRFLOW_REQUIREMENTS))
	cp requirements/airflow.txt $(AIRFLOW_REQUIREMENTS)

$(DAGS_REQUIREMENTS): $(BUILD_ROOT)
	mkdir -p $(shell dirname $(DAGS_REQUIREMENTS))
	cp $(REQUIREMENTS_TXT_LOCATION) $(DAGS_REQUIREMENTS)

$(DAGS): $(BUILD_ROOT)
	mkdir -p $(shell dirname $(DAGS))
	cp -R $(EMBEDDED_DAGS_LOCATION) $(DAGS)

$(BUILD_ROOT):
	mkdir -p $(BUILD_ROOT)

travis-env:
	travis env set DOCKER_EMAIL $(DOCKER_EMAIL)
	travis env set DOCKER_USERNAME $(DOCKER_USERNAME)
	travis env set DOCKER_PASSWORD $(DOCKER_PASSWORD)

test:
	@echo There are no tests available for now. Skipping

save-docker-cache: $(DOCKER_CACHE)
	docker save $(IMAGE) $(shell docker history -q $(IMAGE) | tail -n +2 | grep -v \<missing\> | tr '\n' ' ') > $(SAVED_IMAGE)
	ls -lah $(DOCKER_CACHE)

load-docker-cache: $(DOCKER_CACHE)
	if [ -e $(SAVED_IMAGE) ]; then docker load < $(SAVED_IMAGE); fi

$(DOCKER_CACHE):
	mkdir -p $(DOCKER_CACHE)

create:
	if ! kubectl get namespace $(NAMESPACE) >/dev/null 2>&1; then \
	  kubectl create namespace $(NAMESPACE); \
	fi
	kubectl create -f airflow.all.yaml --namespace $(NAMESPACE)

apply:
	kubectl apply -f airflow.all.yaml --namespace $(NAMESPACE)

delete:
	kubectl delete -f airflow.all.yaml --namespace $(NAMESPACE)

list-pods:
	kubectl get po -a --namespace $(NAMESPACE)

browse-web:
	minikube service web -n $(NAMESPACE)

browse-flower:
	minikube service flower -n $(NAMESPACE)
