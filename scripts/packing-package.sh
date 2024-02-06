#!/bin/bash

mkdir -p dist/layers/deps

cp package*.json dist/layers/deps/
cp yarn.lock dist/layers/deps/
cd dist/layers/deps

yarn --frozen-lockfile
