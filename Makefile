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
DOCKER_CACHE ?= docker-cache
SAVED_IMAGE ?= $(DOCKER_CACHE)/image-$(AIRFLOW_VERSION)-$(KUBECTL_VERSION).tar

NAMESPACE ?= airflow-dev

.PHONY: build clean

clean:
	rm -Rf build

build: $(DOCKERFILE) $(ROOTFS) $(AIRFLOW_CONF) $(ENTRYPOINT_SH)
	cd $(BUILD_ROOT) && docker build -t $(IMAGE) . && docker tag $(IMAGE) $(ALIAS)

publish:
	docker push $(IMAGE) && docker push $(ALIAS)

$(DOCKERFILE): $(BUILD_ROOT)
	sed -e 's/%%KUBECTL_VERSION%%/'"$(KUBECTL_VERSION)"'/g;' -e 's/%%AIRFLOW_VERSION%%/'"$(AIRFLOW_VERSION)"'/g;' Dockerfile.template > $(DOCKERFILE)

$(ROOTFS): $(BUILD_ROOT)
	mkdir -p rootfs
	cp -R rootfs $(ROOTFS)

$(AIRFLOW_CONF): $(BUILD_ROOT)
	mkdir -p $(shell dirname $(AIRFLOW_CONF))
	cp config/airflow.cfg $(AIRFLOW_CONF)

$(ENTRYPOINT_SH): $(BUILD_ROOT)
	mkdir -p $(shell dirname $(ENTRYPOINT_SH))
	cp script/entrypoint.sh $(ENTRYPOINT_SH)

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
