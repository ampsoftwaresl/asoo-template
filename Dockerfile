FROM ubuntu:noble
LABEL maintainer="AMP Software, S.L. <odoo@ampsoftware.com>"

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV LANG C.UTF-8

ENV DEBIAN_FRONTEND=noninteractive

# ==========================
# Dependencias bases
# ==========================
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dirmngr \
    fonts-noto-cjk \
    gnupg \
    libssl-dev \
    node-less \
    npm \
    python3 \
    python3-dev \
    python3-venv \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    git \
    unzip \
    wget \
    locales \
    lsb-release \
    xz-utils \
 && rm -rf /var/lib/apt/lists/*

# ==========================
# 🐘 Cliente PostgreSQL
# ==========================
RUN echo "deb http://apt.postgresql.org/pub/repos/apt noble-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/pgdg.list

# ==========================
# 🖨️ wkhtmltopdf (Jammy compatible)
# ==========================
RUN apt-get update && \
    if [ -z "${TARGETARCH}" ]; then TARGETARCH="$(dpkg --print-architecture)"; fi && \
    case ${TARGETARCH} in \
        "amd64") WKHTMLTOPDF_ARCH=amd64 ;; \
        "arm64") WKHTMLTOPDF_ARCH=arm64 ;; \
        "ppc64le"|"ppc64el") WKHTMLTOPDF_ARCH=ppc64el ;; \
    esac && \
    curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${WKHTMLTOPDF_ARCH}.deb && \
    apt-get install -y --no-install-recommends ./wkhtmltox.deb && \
    rm -rf wkhtmltox.deb /var/lib/apt/lists/*


# Instala Odoo desde .deb oficial
ENV ODOO_VERSION 19.0
ARG ODOO_RELEASE=20251003
ARG ODOO_SHA=ec3b491d655c22a8b493b83e297a9a6bd91ff86c
RUN curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
    && echo "${ODOO_SHA} odoo.deb" | sha1sum -c - \
    && apt-get update \
    && apt-get install -y --no-install-recommends ./odoo.deb \
    && rm -rf /var/lib/apt/lists/* odoo.deb

# ==========================
# 🐍 Entorno virtual Python
# ==========================
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install python requirements.txt
RUN pip3 install --upgrade pip
ADD ./requirements.txt /requirements.txt
RUN pip3 install -r /requirements.txt 

# ==========================
# 📦 Instalación de librerías Python
# ==========================
RUN pip install --upgrade pip setuptools wheel && \
    pip install \
        num2words xlwt psycopg2-binary \
        pdfminer.six qrcode python-slugify \
        watchdog phonenumbers vobject xlrd odfpy \
        lxml-html-clean

# ==========================
# Localización
# ==========================
RUN locale-gen es_ES.UTF-8 && update-locale LANG=es_ES.UTF-8
ENV LANG=es_ES.UTF-8
ENV LANGUAGE=es_ES:es
ENV LC_ALL=es_ES.UTF-8

# ==========================
# Limpieza final
# ==========================
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY ./entrypoint.sh /
COPY ./config/odoo.conf /etc/odoo/
RUN chown odoo /etc/odoo/odoo.conf

RUN mkdir -p /mnt/extra-addons \
    && chown -R odoo /mnt/extra-addons
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

EXPOSE 8069 8071 8072
ENV ODOO_RC /etc/odoo/odoo.conf
USER odoo
ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
