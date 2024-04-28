FROM alpine:3.12 as alpine-dev
RUN apk add --no-cache gcc musl-dev make git openssh git-lfs

FROM alpine-dev as build
WORKDIR /build
ARG COMMIT=HEAD
RUN git clone https://github.com/janet-lang/janet.git janet
WORKDIR /build/janet
RUN git checkout $COMMIT
# Use COPY instead of git clone to work with a local janet install
# COPY . .
RUN make PREFIX=/app -j
RUN make test
RUN make PREFIX=/app install

ARG JPM_COMMIT=HEAD
WORKDIR /build
RUN git clone https://github.com/janet-lang/jpm jpm
WORKDIR /build/jpm
RUN git checkout $JPM_COMMIT
RUN PREFIX=/app /app/bin/janet bootstrap.janet

FROM alpine-dev as dev
COPY --from=build /app /app
ENV PATH="/app/bin:$PATH"
WORKDIR /app
CMD ["ash"] 

FROM alpine as core
RUN apk add --no-cache gcc musl-dev make git bash openssh git-lfs curl curl-dev libcurl ffmpeg age mbuffer fzf rclone caddy ripgrep entr direnv ugrep libuuid uuidgen
COPY --from=build /app/ /app/
ENV PATH="/app/bin:$PATH"
WORKDIR /app
RUN jpm install https://github.com/janet-lang/spork
RUN jpm install https://github.com/janet-lang/sqlite3
RUN jpm install https://github.com/janet-lang/jhydro
RUN jpm install https://github.com/janet-lang/circlet
RUN jpm install https://github.com/CosmicToast/jurl
RUN jpm install https://github.com/tionis/toolbox
RUN jpm install https://github.com/andrewchambers/janet-uri
RUN jpm install https://github.com/andrewchambers/janet-flock
RUN jpm install https://github.com/MorganPeterson/jermbox
RUN jpm install https://github.com/andrewchambers/janet-big
RUN jpm install https://github.com/tionis/remarkable
RUN jpm install https://github.com/joy-framework/uuid
RUN jpm install https://git.sr.ht/~pepe/chidi/
RUN jpm install https://git.sr.ht/~pepe/gp/
RUN jpm install https://github.com/MorganPeterson/jermbox
RUN jpm install https://github.com/tionis/jeff
CMD ["janet"] 
