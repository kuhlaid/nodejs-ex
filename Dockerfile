FROM registry.stage.redhat.io/ubi8/ubi-minimal:8.10
# might want to use httpd image instead (does not work)
# FROM registry.stage.redhat.io/rhel9/httpd-24

EXPOSE 8080,8443

# Add $HOME/node_modules/.bin to the $PATH, allowing user to make yarn scripts
# available on the CLI without using yarn's --global installation mode
# This image will be initialized with "yarn run $YARN_RUN"
# See https://docs.yarnjs.com/misc/scripts, and your repo's package.json
# file for possible values of YARN_RUN
# Description
# Environment:
# * $YARN_RUN - Select an alternate / custom runtime mode, defined in your package.json files' scripts section (default: yarn run "start").
# Expose ports:
# * 8080 - Unprivileged port used by nodejs application
ENV APP_ROOT=/opt/app-root \
    # The $HOME is not set by default, but some applications need this variable
    HOME=/opt/app-root/src \
    YARN_RUN=start \
    PLATFORM="el8" \
    NODEJS_VERSION=20 \
    NAME=nodejs

ENV SUMMARY="Minimal image for running Node.js $NODEJS_VERSION applications" \
    DESCRIPTION="Node.js $NODEJS_VERSION available as container is a base platform for \
running various Node.js $NODEJS_VERSION applications and frameworks. \
Node.js is a platform built on Chrome's JavaScript runtime for easily building \
fast, scalable network applications. Node.js uses an event-driven, non-blocking I/O model \
that makes it lightweight and efficient, perfect for data-intensive real-time applications \
that run across distributed devices." \
    YARN_CONFIG_PREFIX=$HOME/.yarn-global \
    PATH=$HOME/node_modules/.bin/:$HOME/.yarn-global/bin/:$PATH

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Node.js $NODEJS_VERSION Minimal" \
      io.openshift.expose-services="8443:https" \
      io.openshift.tags="builder,$NAME,${NAME}${NODEJS_VERSION}" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i" \
      io.s2i.scripts-url="image:///usr/libexec/s2i" \
      com.redhat.dev-mode="DEV_MODE:false" \
      com.redhat.deployments-dir="${APP_ROOT}/src" \
      com.redhat.dev-mode.port="DEBUG_PORT:5858" \
      com.redhat.component="${NAME}-${NODEJS_VERSION}-minimal-container" \
      name="ubi8/$NAME-$NODEJS_VERSION-minimal" \
      version="1" \
      com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI" \
      maintainer="SoftwareCollections.org <sclorg@redhat.com>" \
      help="For more information visit https://github.com/sclorg/s2i-nodejs-container"

# pull in yarn for package management (since NPM can cause headaches with OpenShift)
RUN curl -sL https://dl.yarnpkg.com/rpm/yarn.repo -o /etc/yum.repos.d/yarn.repo

# nodejs-full-i18n is included for error strings
RUN INSTALL_PKGS="nodejs nodejs-nodemon nodejs-full-i18n yarn findutils tar which" && \
    microdnf -y module disable nodejs && \
    microdnf -y module enable nodejs:$NODEJS_VERSION && \
    microdnf --nodocs --setopt=install_weak_deps=0 install $INSTALL_PKGS && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \
    microdnf clean all && \
    rm -rf /mnt/rootfs/var/cache/* /mnt/rootfs/var/log/dnf* /mnt/rootfs/var/log/yum.*

# Copy package.json and yarn.lock
# COPY package*.json ./
# COPY yarn.lock ./

# Drop the root user and make the content of /opt/app-root owned by user 1001
RUN mkdir -p "$HOME" && chown -R 1001:0 "$APP_ROOT" && chmod -R ug+rwx "$APP_ROOT"

WORKDIR "$HOME"

COPY ./ "$HOME"

# Install packages 
RUN yarn install

ENV NODE_ENV production


# WORKDIR "$HOME"
USER 1001
CMD ["yarn", "run", "start"]