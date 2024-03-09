SHELL := /bin/bash
TYPST := $(shell command -v typst 2> /dev/null)

all: calendar.yaml $(patsubst %.typ,%.pdf,$(wildcard *.typ))

calendar.yaml:
	./generate_data.py

ifndef TYPST
	$(error "typst is not available; please install typst")
endif

%.pdf: %.typ
ifndef TYPST
	$(error "typst is not available; please install typst")
endif
ifndef TIMING
	$(TYPST) compile $< $@
else
	$(TYPST) compile --timings $(basename $<)-timing.json $< $@
endif
