#!/bin/bash
cd "$(dirname "$0")"
elm make src/Main.elm --output=elm.js
