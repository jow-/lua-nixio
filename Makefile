OS            = Linux
#NIXIO_TLS    ?= openssl
NIXIO_SHADOW ?= $(shell echo 'int main(void){ return !getspnam("root"); }' | $(CC) $(CFLAGS) -include shadow.h -xc -o/dev/null - 2>/dev/null && echo yes)
NIXIO_SO      = nixio.so
NIXIO_LDFLAGS = -llua -lm -ldl
CFLAGS       += -std=gnu99

ifeq (,$(findstring Darwin,$(OS)))
	NIXIO_LDFLAGS += -lcrypt -shared
else
	NIXIO_LDFLAGS += -bundle -undefined dynamic_lookup
	EXTRA_CFLAGS += -D__DARWIN__
endif

NIXIO_OBJ = src/nixio.o src/socket.o src/sockopt.o src/bind.o src/address.o \
	    src/protoent.o src/poll.o src/io.o src/file.o src/splice.o src/process.o \
	    src/syslog.o src/bit.o src/binary.o src/fs.o src/user.o \
	    $(if $(NIXIO_TLS),src/tls-crypto.o src/tls-context.o src/tls-socket.o,)

ifeq ($(NIXIO_TLS),axtls)
	TLS_CFLAGS = -include src/axtls-compat.h
	TLS_DEPENDS = src/axtls-compat.o
	NIXIO_OBJ += src/axtls-compat.o
	NIXIO_LDFLAGS += -Wl,-Bstatic -laxtls -Wl,-Bdynamic
endif

ifeq ($(NIXIO_TLS),openssl)
	NIXIO_LDFLAGS += -lssl -lcrypto
endif

ifeq ($(NIXIO_TLS),cyassl)
	NIXIO_LDFLAGS += -lcyassl
endif

ifeq ($(NIXIO_TLS),)
	NIXIO_CFLAGS += -DNO_TLS
endif

ifneq ($(NIXIO_SHADOW),yes)
	NIXIO_CFLAGS += -DNO_SHADOW
endif


ifeq ($(OS),SunOS)
	NIXIO_LDFLAGS += -lsocket -lnsl -lsendfile
endif

ifneq (,$(findstring MINGW,$(OS))$(findstring mingw,$(OS))$(findstring Windows,$(OS)))
	NIXIO_CROSS_CC:=$(shell which i586-mingw32msvc-cc)
ifneq (,$(NIXIO_CROSS_CC))
	CC:=$(NIXIO_CROSS_CC)
endif
	NIXIO_OBJ += src/mingw-compat.o
	NIXIO_LDFLAGS_POST:=-llua -lssl -lcrypto -lws2_32 -lgdi32
	FPIC:=
	EXTRA_CFLAGS += -D_WIN32_WINNT=0x0501
	LUA_CFLAGS:=
	NIXIO_SO:=nixio.dll
	NIXIO_LDFLAGS:=
endif


%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(NIXIO_CFLAGS) $(LUA_CFLAGS) $(FPIC) -c -o $@ $< 

ifneq ($(NIXIO_TLS),)
src/tls-crypto.o: $(TLS_DEPENDS) src/tls-crypto.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(NIXIO_CFLAGS) $(LUA_CFLAGS) $(FPIC) $(TLS_CFLAGS) -c -o $@ src/tls-crypto.c

src/tls-context.o: $(TLS_DEPENDS) src/tls-context.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(NIXIO_CFLAGS) $(LUA_CFLAGS) $(FPIC) $(TLS_CFLAGS) -c -o $@ src/tls-context.c
	
src/tls-socket.o: $(TLS_DEPENDS) src/tls-socket.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(NIXIO_CFLAGS) $(LUA_CFLAGS) $(FPIC) $(TLS_CFLAGS) -c -o $@ src/tls-socket.c

src/axtls-compat.o: $(TLS_DEPENDS) src/axtls-compat.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(NIXIO_CFLAGS) $(LUA_CFLAGS) $(FPIC) $(TLS_CFLAGS) -c -o $@ src/axtls-compat.c
endif	

compile: $(NIXIO_OBJ)
	$(CC) $(LDFLAGS) $(SHLIB_FLAGS) -o src/$(NIXIO_SO) $(NIXIO_OBJ) $(NIXIO_LDFLAGS) $(NIXIO_LDFLAGS_POST)
	mkdir -p dist/usr/lib/lua
	cp src/$(NIXIO_SO) dist/usr/lib/lua/$(NIXIO_SO)

clean:
	rm -f src/*.o src/*.so src/*.a src/*.dll

install: compile
	mkdir -p $(DESTDIR)
	cp -pR dist/* $(DESTDIR)/
