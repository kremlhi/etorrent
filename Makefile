all:
	rebar3 compile

shell:
	rebar3 shell

release:
	rebar3 release

clean:
	$(RM) -r _build

