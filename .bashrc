#!/bin/bash

test -s ~/.alias && . ~/.alias || true

export PATH=$PATH:$HOME/bin
