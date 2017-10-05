$(INST_LUADIR)/apicast:
	mkdir -p $@

install: $(INST_LUADIR)/apicast
	@echo --- install
	cp -R apicast/src/* $(INST_LUADIR)/
	cp apicast/bin/apicast* $(INST_BINDIR)/
	cp -r apicast/*.d apicast/conf $(INST_CONFDIR)
