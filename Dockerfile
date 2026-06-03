# Reproducible dev/test container for the platform-stack adapter.
#
#   docker build -t platform-stack .                 # build the image
#   docker run --rm platform-stack                   # default: fmt + build + smoke + contract test
#   docker run --rm platform-stack xvfb-run -a zig build test-tdd   # window/input behavioral suite
#
# SDL3 is built from source by the castholm/SDL Zig package (headers vendored),
# so the *build* needs no system -dev packages — only the X11/Wayland **runtime**
# libs (+ xvfb) to actually open a window for the behavioral tests. The contract
# suite (`scripts/ci.sh`) needs no display. First `zig build` fetches the pinned
# deps (network).
FROM ubuntu:24.04
ARG ZIG_VERSION=0.16.0
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl xz-utils git python3 python3-pip \
      xvfb \
      libx11-6 libxext6 libxrandr2 libxi6 libxcursor1 libxfixes3 \
      libxkbcommon0 libwayland-client0 libgl1 \
    && rm -rf /var/lib/apt/lists/*

# Zig, pinned — URL resolved from the official release index.
RUN set -eux; \
    url="$(curl -fsSL https://ziglang.org/download/index.json \
      | python3 -c "import sys,json;print(json.load(sys.stdin)['${ZIG_VERSION}']['x86_64-linux']['tarball'])")"; \
    curl -fsSL "$url" -o /tmp/zig.tar.xz; \
    mkdir -p /opt/zig; tar -xJf /tmp/zig.tar.xz -C /opt/zig --strip-components=1; \
    ln -s /opt/zig/zig /usr/local/bin/zig; rm /tmp/zig.tar.xz; zig version

WORKDIR /work
COPY . .
RUN python3 -m pip install --break-system-packages --quiet pyyaml || true

CMD ["bash", "scripts/ci.sh"]
