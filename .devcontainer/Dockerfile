# OpenStack Freezer umbrella development environment.
#
# Reproduces the builder environment: per-submodule venvs (venv-mandatory
# rule), git-review for human pushes, npx for repomix/autoskills, and the
# umbrella scripts. Root-only by design.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip python3-dev \
        git ca-certificates curl locales \
        nodejs npm \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

RUN python3 -m pip install --no-cache-dir --upgrade pip \
    && python3 -m pip install --no-cache-dir git-review tox

WORKDIR /workspace

CMD ["sleep", "infinity"]