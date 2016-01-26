FROM xcgd/ubuntu4base
MAINTAINER tedi3231@qq.com 

# generate locales
RUN locale-gen en_US.UTF-8 && update-locale
RUN echo 'LANG="en_US.UTF-8"' > /etc/default/locale

# Add the PostgreSQL PGP key to verify their Debian packages.
# It should be the same key as https://www.postgresql.org/media/keys/ACCC4CF8.asc
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8

# Add PostgreSQL's repository. It contains the most recent stable release
#     of PostgreSQL, ``9.4``.
# install dependencies as distrib packages when system bindings are required
# some of them extend the basic odoo requirements for a better "apps" compatibility
# most dependencies are distributed as wheel packages at the next step
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
        apt-get update && \
        apt-get -yq install \
            adduser \
            ghostscript \
            postgresql-client-9.4 \
            python \
                python-pip \
                python-imaging \
                python-pychart python-libxslt1 xfonts-base xfonts-75dpi \
                libxrender1 libxext6 fontconfig \
                python-zsi \
                python-lasso \
                libzmq3 \
                gdebi

RUN pip install leancloud-sdk

ADD sources/pip-checksums.txt /opt/sources/pip-checksums.txt
# use wheels from our public wheelhouse for proper versions of listed packages
# as described in sourced pip-req.txt
# these are python dependencies for odoo and "apps" as precompiled wheel packages

RUN pip install peep && \
    peep install --upgrade --use-wheel --no-index --pre \
        --find-links=https://wheelhouse.xcg.io/trusty/odoo/ \
        -r /opt/sources/pip-checksums.txt

# must unzip this package to make it visible as an odoo external dependency
RUN easy_install -UZ py3o.template==0.9.7

# install wkhtmltopdf based on QT5
ADD http://download.gna.org/wkhtmltopdf/0.12/0.12.2.1/wkhtmltox-0.12.2.1_linux-trusty-amd64.deb /opt/sources/wkhtmltox.deb
RUN gdebi -n /opt/sources/wkhtmltox.deb

# create the odoo user
RUN adduser --home=/opt/odoo --disabled-password --gecos "" --shell=/bin/bash odoo

# ADD sources for the oe components
# ADD an URI always gives 600 permission with UID:GID 0 => need to chmod accordingly
# /!\ carefully select the source archive depending on the version
# ADD https://wheelhouse.xcg.io/odoo/odoo8.tgz /opt/odoo/odoo.tgz
ADD http://nightly.odoo.com/8.0/nightly/src/odoo_8.0.20160126.tar.gz /opt/odoo/odoo.tar.gz
# RUN echo "1df8d5a3ec29f83435340f46e771157d70b719ac789976a575ba2697078c68c3 /opt/odoo/odoo.tgz" | sha256sum -c -
RUN chown odoo:odoo /opt/odoo/odoo.tar.gz

# changing user is required by odoo which won't start with root
# makes the container more unlikely to be unwillingly changed in interactive mode
USER odoo

RUN /bin/bash -c "mkdir -p /opt/odoo/{bin,etc,sources/odoo,additional_addons,data}" && \
    cd /opt/odoo/sources/ && \
    tar xzf /opt/odoo/odoo.tar.gz && \
	mv /opt/odoo/sources/odoo-8.0-20160126 /opt/odoo/sources/odoo
RUN ls /opt/odoo/sources
RUN ls /opt/odoo/
#rm /opt/odoo/odoo.tar.gz

RUN /bin/bash -c "mkdir -p /opt/odoo/var/{run,log,egg-cache}"

# Execution environment
USER 0
ADD sources/odoo.conf /opt/sources/odoo.conf
WORKDIR /app
VOLUME ["/opt/odoo/var", "/opt/odoo/etc", "/opt/odoo/additional_addons", "/opt/odoo/data","/opt/odoo/sources"]
# Set the default entrypoint (non overridable) to run when starting the container
# ENTRYPOINT ["/app/bin/boot"]
ENTRYPOINT ["/bin/bash"]
# CMD ["help"]
# Expose the odoo ports (for linked containers)
EXPOSE 8069 8072
ADD bin /app/bin/
RUN chmod +x /app/bin/boot
