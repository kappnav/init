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
FROM registry.access.redhat.com/ubi7-minimal

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

ENV NODE_VERSION 8.11.4

ENV YARN_VERSION 1.13.0

# Install node
RUN microdnf update -y \
  && microdnf -y install shadow-utils tar xz gzip \
  && useradd --uid 1001 --gid 0 --shell /bin/bash --create-home node \
  && ARCH=$(uname -p) \
   && if [ "$ARCH" != "ppc64le" ] && [ "$ARCH" != "s390x" ]; then \
     ARCH="x64" ; \
  fi \
  # gpg keys listed at https://github.com/nodejs/node#release-keys
  && set -ex \
  && for key in \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
  && set -ex \
  && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && microdnf remove -y shadow-utils tar xz gzip \
  && microdnf clean all

# RUN yum -y remove mariadb-devel

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

# get application CRD from Kubernetes Application SIG
# RUN wget https://raw.githubusercontent.com/kubernetes-sigs/application/master/config/crds/app_v1beta1_application.yaml -P /initfiles
RUN curl -fsSLO --compressed https://raw.githubusercontent.com/kubernetes-sigs/application/master/config/crds/app_v1beta1_application.yaml \
    && mv app_v1beta1_application.yaml /initfiles/

# set working dir as it was when using ubi7/nodejs-8 base image
RUN mkdir -p /opt/app-src/root \
   && chown 1001:0 /opt/app-src/root
USER 1001
WORKDIR /opt/app-src/root
CMD /initfiles/init-kappnav.sh
