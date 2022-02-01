FROM alpine:3.12 as alpine-dev
RUN apk add --no-cache gcc musl-dev make git

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
RUN apk add --no-cache gcc musl-dev make git bash
COPY --from=build /app/ /app/
ENV PATH="/app/bin:$PATH"
WORKDIR /app
CMD ["janet"] 
