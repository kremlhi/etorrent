all:
	rebar3 compile

dev-release:
	rebar3 release

release:
	rebar3 release

clean:
	$(RM) -r _build

