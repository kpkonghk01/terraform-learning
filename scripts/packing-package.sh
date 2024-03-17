#!/bin/bash

mkdir -p dist/deps

cp package*.json dist/deps/
cp yarn.lock dist/deps/
cd dist/deps

yarn --frozen-lockfile
