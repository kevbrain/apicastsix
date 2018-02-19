$(INST_LUADIR)/apicast:
	mkdir -p $@

install: $(INST_LUADIR)/apicast
	@echo --- install
	cp -R gateway/src/* $(INST_LUADIR)/
	cp gateway/bin/apicast* $(INST_BINDIR)/
	cp -r gateway/*.d gateway/conf{,ig} gateway/libexec $(INST_CONFDIR)
