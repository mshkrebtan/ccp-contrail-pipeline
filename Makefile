SOURCE_BRANCH ?= "R3.0.3.x"
GIT_CONTRAIL_BASE ?= ssh://admin@ci.ccp-poc.cloudlab.cz:29418
CWD=$(shell pwd)

OS   ?= debian
DIST ?= jessie
ARCH ?= amd64

all: checkout build-image build-source build-binary

help:
	@echo "all           Build everything"
	@echo "build-image   Build image for package build"
	@echo "shell         Enter shell in build container"
	@echo "build-shell   Enter build env for given PACKAGE"
	@echo "build-source  Build debian source packages"
	@echo "build-binary  Build debian binary packages"
	@echo "clean         Cleanup after previous builds"

build-image:
	docker build -t build-$(OS)-$(DIST)-$(ARCH) -f docker/$(OS)-$(DIST)-$(ARCH).Dockerfile docker

shell:
	docker run -u 1000 -it -v $(CWD):$(CWD) -w $(CWD) --rm=true build-$(OS)-$(DIST)-$(ARCH) bash

build-shell:
	$(eval PACKAGE ?= contrail)
	(rm -rf src/build/${PACKAGE} || true)
	docker run -u 1000 -it -v $(CWD):$(CWD) -w $(CWD) --rm=true build-$(OS)-$(DIST)-$(ARCH) /bin/bash -c "dpkg-source -x src/build/packages/${PACKAGE}_*.dsc src/build/${PACKAGE}; \
		cd src/build/${PACKAGE}; sudo apt-get update; dpkg-checkbuilddeps 2>&1|rev|cut -d : -f 1|rev|sed 's,(.*),,g'|xargs sudo apt-get install -y; bash"

clean:
	rm -rf src/build

build-source: \
	fetch-third-party \
	build-source-contrail-web-core \
	build-source-contrail-web-controller \
	build-source-contrail \
	build-source-contrail-vrouter-dpdk \
	build-source-ifmap-server \
	build-source-neutron-plugin-contrail \
	build-source-ceilometer-plugin-contrail \
	build-source-contrail-heat

fetch-third-party:
	docker run -u 1000 -t -v $(CWD):$(CWD) -w $(CWD)/src/third_party --rm=true build-$(OS)-$(DIST)-$(ARCH) python fetch_packages.py
	docker run -u 1000 -t -v $(CWD):$(CWD) -w $(CWD)/src/contrail-webui-third-party --rm=true build-$(OS)-$(DIST)-$(ARCH) python fetch_packages.py -f packages.xml
	rm -rf src/contrail-web-core/node_modules
	mkdir src/contrail-web-core/node_modules
	cp -rf src/contrail-webui-third-party/node_modules/* src/contrail-web-core/node_modules/

build-source-%:
	$(eval PACKAGE := $(patsubst build-source-%,%,$@))
	(rm -f src/build/packages/${PACKAGE}_* || true)
	docker run -u 1000 -t -v $(CWD):$(CWD) -w $(CWD)/src --rm=true build-$(OS)-$(DIST)-$(ARCH) make -f packages.make source-package-${PACKAGE}

build-binary: \
	build-binary-contrail-web-core \
	build-binary-contrail-web-controller \
	build-binary-contrail \
	build-binary-contrail-vrouter-dpdk \
	build-binary-ifmap-server \
	build-binary-neutron-plugin-contrail \
	build-binary-ceilometer-plugin-contrail \
	build-binary-contrail-heat

build-binary-%:
	$(eval PACKAGE := $(patsubst build-binary-%,%,$@))
	(rm -rf src/build/${PACKAGE} || true)
	docker run -u 1000 -t -v $(CWD):$(CWD) -w $(CWD) --rm=true build-$(OS)-$(DIST)-$(ARCH) /bin/bash -c "dpkg-source -x src/build/packages/${PACKAGE}_*.dsc src/build/${PACKAGE}; \
		cd src/build/${PACKAGE}; sudo apt-get update; dpkg-checkbuilddeps 2>&1|rev|cut -d : -f 1|rev|sed 's,(.*),,g'|xargs sudo apt-get install -y; \
		cd src/build/${pkg}; debuild --no-lintian -uc -us ${opts}"

checkout: \
	checkout-contrail-build \
	checkout-contrail-controller \
	checkout-contrail-vrouter \
	checkout-contrail-third-party \
	checkout-contrail-generateDS \
	checkout-contrail-sandesh \
	checkout-contrail-packages \
	checkout-contrail-nova-vif-driver \
	checkout-contrail-neutron-plugin \
	checkout-contrail-nova-extensions \
	checkout-contrail-heat \
	checkout-contrail-ceilometer-plugin \
	checkout-contrail-web-storage \
	checkout-contrail-web-server-manager \
	checkout-contrail-web-controller \
	checkout-contrail-web-core \
	checkout-contrail-webui-third-party
	(test -e src/SConstruct || ln -s tools/build/SConstruct src/SConstruct)
	(test -e src/packages.make || ln -s tools/packages/packages.make src/packages.make)

define checkout-component
	test -d src/${target} || mkdir -p src/${target}
	cd src/${target} ;\
	git --git-dir=.git remote 2>/dev/null |  grep origin >/dev/null \
	|| { \
	   echo "Create a git repository." ;\
	   git init ;\
	   git remote add \
	   	origin $(GIT_CONTRAIL_BASE)/${component}.git ;\
	   } ;\
	git fetch origin ;\
       	git checkout $(SOURCE_BRANCH) ;\
	git reset --hard origin/$(SOURCE_BRANCH) \
	|| { \
	   echo "Checkout $(3) instead." ;\
	   git reset --hard origin/$(3) ;\
	   }
endef

checkout-contrail-build:
	$(eval component = contrail-build)
	$(eval target = tools/build)
	$(call checkout-component,${target},${component})

checkout-contrail-controller:
	$(eval component = contrail-controller)
	$(eval target = controller)
	$(call checkout-component,${target},${component})

checkout-contrail-vrouter:
	$(eval component = contrail-vrouter)
	$(eval target = vrouter)
	$(call checkout-component,${target},${component})

checkout-contrail-third-party:
	$(eval component = contrail-third-party)
	$(eval target = third_party)
	$(call checkout-component,${target},${component})

checkout-contrail-generateDS:
	$(eval component = contrail-generateDS)
	$(eval target = tools/generateds)
	$(call checkout-component,${target},${component})

checkout-contrail-sandesh:
	$(eval component = contrail-sandesh)
	$(eval target = tools/sandesh)
	$(call checkout-component,${target},${component})

checkout-contrail-packages:
	$(eval component = contrail-packages)
	$(eval target = tools/packages)
	$(call checkout-component,${target},${component})

checkout-contrail-nova-vif-driver:
	$(eval component = contrail-nova-vif-driver)
	$(eval target = openstack/nova_contrail_vif)
	$(call checkout-component,${target},${component})

checkout-contrail-neutron-plugin:
	$(eval component = contrail-neutron-plugin)
	$(eval target = openstack/neutron_plugin)
	$(call checkout-component,${target},${component})

checkout-contrail-nova-extensions:
	$(eval component = contrail-nova-extensions)
	$(eval target = openstack/nova_extensions)
	$(call checkout-component,${target},${component})

checkout-contrail-heat:
	$(eval component = contrail-heat)
	$(eval target = openstack/contrail-heat)
	$(call checkout-component,${target},${component})

checkout-contrail-ceilometer-plugin:
	$(eval component = contrail-ceilometer-plugin)
	$(eval target = openstack/ceilometer_plugin)
	$(call checkout-component,${target},${component},master)

checkout-contrail-web-storage:
	$(eval component = contrail-web-storage)
	$(eval target = contrail-web-storage)
	$(call checkout-component,${target},${component})

checkout-contrail-web-server-manager:
	$(eval component = contrail-web-server-manager)
	$(eval target = contrail-web-server-manager)
	$(call checkout-component,${target},${component})

checkout-contrail-web-controller:
	$(eval component = contrail-web-controller)
	$(eval target = contrail-web-controller)
	$(call checkout-component,${target},${component})

checkout-contrail-web-core:
	$(eval component = contrail-web-core)
	$(eval target = contrail-web-core)
	$(call checkout-component,${target},${component})

checkout-contrail-webui-third-party:
	$(eval component = contrail-webui-third-party)
	$(eval target = contrail-webui-third-party)
	$(call checkout-component,${target},${component})
