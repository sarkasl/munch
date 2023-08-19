#!/bin/bash

erl -pa ./build/dev/erlang/*/ebin -eval 'markdown:main(), halt().' -noshell
