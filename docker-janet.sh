#!/bin/bash

DOCKER_REPO=tionis

LAST_COMMIT=$(<last_commit.txt)
CURRENT_COMMIT=$(curl -L -s -H 'Accept: application/json' https://api.github.com/repos/janet-lang/janet/branches/master | jq -j .commit.sha)

#REVISION="$CURRENT_COMMIT"
DATE=$(date '+%Y-%m-%dT%H:%M:%S')

function docker-build () {
    TAGNAME=$1
    COMMIT=$2
    JPM_COMMIT=$3
    echo "Building with TAGNAME=$TAGNAME and COMMIT=$COMMIT"
    #PLATFORMS="linux/amd64,linux/386,linux/arm64,linux/arm/v7,linux/arm/v6"
	PLATFORMS="linux/amd64"

    docker buildx build --platform "$PLATFORMS" . --push --target=core --tag "$DOCKER_REPO"/janet:"$TAGNAME" \
        --build-arg "COMMIT=$COMMIT" \
        --build-arg "JPM_COMMIT=$JPM_COMMIT" \
        --label "org.opencontainers.image.revision=$COMMIT" \
        --label "org.opencontainers.image.created=$DATE" \
        --label "org.opencontainers.image.source=https://github.com/janet-lang/janet"
    docker buildx build --platform "$PLATFORMS" . --push --target=dev --tag "$DOCKER_REPO"/janet-sdk:"$TAGNAME" \
        --build-arg "COMMIT=$COMMIT" \
        --build-arg "JPM_COMMIT=$JPM_COMMIT" \
        --label "org.opencontainers.image.revision=$COMMIT" \
        --label "org.opencontainers.image.created=$DATE" \
        --label "org.opencontainers.image.source=https://github.com/janet-lang/janet"
}

if [ "$LAST_COMMIT" == "$CURRENT_COMMIT" ]; then
    echo "No new commits since $CURRENT_COMMIT"
    exit 0
fi

echo "$DOCKER_PASSWORD" | docker login -u tionis --password-stdin
echo "Building image for latest commit $CURRENT_COMMIT, last commit was $LAST_COMMIT"
docker-build latest "$CURRENT_COMMIT" "$HEAD"

LAST_TAG=$(<last_tag.txt)
CURRENT_TAG=$(curl -L -s -H 'Accept: application/json' https://api.github.com/repos/janet-lang/janet/tags | jq -j .[0].name)

if [ "$LAST_TAG" == "$CURRENT_TAG" ]; then
    echo "No new tags since $CURRENT_TAG"
else
    CURRENT_TAG_COMMIT=$(curl -L -s -H 'Accept: application/json' https://api.github.com/repos/janet-lang/janet/tags | jq -j .[0].commit.sha)

    if [ "$CURRENT_TAG_COMMIT" == "$CURRENT_COMMIT" ]; then
        echo "Tagging image for latest tag $CURRENT_TAG, last tag was $LAST_TAG"
        docker tag "$DOCKER_REPO/janet:latest" "$DOCKER_REPO/janet:$CURRENT_TAG"
        docker tag "$DOCKER_REPO/janet-sdk:latest" "$DOCKER_REPO/janet-sdk:$CURRENT_TAG"
    else
        echo "Building new image for $CURRENT_TAG at commit $CURRENT_TAG_COMMIT"
        docker-build "$CURRENT_TAG" "$CURRENT_TAG_COMMIT"
    fi
fi

#docker push $DOCKER_REPO/janet:latest
#docker push $DOCKER_REPO/janet-sdk:latest

echo "$CURRENT_COMMIT" > last_commit.txt
echo "$CURRENT_TAG" > last_tag.txt

if ! git diff --no-ext-diff --quiet --exit-code; then
    MSG=$(curl -L -s -H 'Accept: application/json' "https://api.github.com/repos/janet-lang/janet/commits/$CURRENT_COMMIT" | jq -j .commit.message)
    git add -A && (printf "[build] Update last_commit:\n\n%s" "$MSG" | git commit -F -) && git push -u origin master
fi
