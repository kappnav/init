#*****************************************************************
#*
#* Copyright 2019 IBM Corporation
#*
#* Licensed under the Apache License, Version 2.0 (the "License");
#* you may not use this file except in compliance with the License.
#* You may obtain a copy of the License at

#* http://www.apache.org/licenses/LICENSE-2.0
#* Unless required by applicable law or agreed to in writing, software
#* distributed under the License is distributed on an "AS IS" BASIS,
#* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#* See the License for the specific language governing permissions and
#* limitations under the License.
#*
#*****************************************************************

# Stage 1: build using node
FROM node:8.11.4 as build

COPY js/ /js/
COPY package.json /js/

RUN cd /js; npm install

# Stage 2: Run node server
FROM registry.access.redhat.com/ubi7/nodejs-8:1-47

ARG VERSION
ARG BUILD_DATE

LABEL name="Application Navigator" \
      vendor="kAppNav" \
      version=$VERSION \
      release=$VERSION \
      created=$BUILD_DATE \
      summary="Initialization image for Application Navigator" \
      description="This image contains initialization logic for Application Navigator"

USER root
RUN yum -y remove mariadb-devel

# install kubectl

RUN  ARCH=$(uname -p) \
   && if [ "$ARCH" != "ppc64le" ] && [ "$ARCH" != "s390x" ]; then \
     ARCH="amd64" ; \
   fi \
   && curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/${ARCH}/kubectl \
   && chmod ug+x ./kubectl \
   && mv ./kubectl /usr/local/bin/kubectl

COPY --from=build --chown=1001:0 /js /js/
COPY --from=build --chown=1001:0 /js/node_modules /js/node_modules/

COPY --chown=1001:0 initfiles/ /initfiles/
COPY --chown=1001:0 crds/ /initfiles/
COPY --chown=1001:0 licenses/ /licenses/

RUN chmod -R 770 /initfiles
USER 1001

# get application CRD from Kubernetes Application SIG
RUN wget https://raw.githubusercontent.com/kubernetes-sigs/application/master/config/crds/app_v1beta1_application.yaml -P /initfiles

CMD /initfiles/init-kappnav.sh
